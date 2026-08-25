import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/odoo_models.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/odoo/odoo_chatter_service.dart';
import '../../../../core/network/odoo/odoo_object_service.dart';
import '../../../../core/network/odoo/odoo_value.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../assignment/domain/entities/assignment.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_draft.dart';
import '../../domain/entities/asset_history.dart';
import '../../domain/entities/asset_query.dart';
import '../../domain/entities/asset_status.dart';
import '../../domain/repositories/asset_repository.dart';
import '../datasources/asset_remote_data_source.dart';
import '../mappers/asset_mapper.dart';
import '../services/asset_note_vocabulary.dart';
import '../services/asset_state_store.dart';
import '../services/asset_status_resolver.dart';

/// The data-layer implementation of [AssetRepository].
///
/// Three jobs, in order:
///
/// 1. **Turn exceptions into values.** Everything is wrapped in [_guard], so a
///    Dio timeout or an Odoo `AccessError` becomes an `Either.left(Failure)`
///    and no exception ever escapes towards a Cubit (spec §22).
/// 2. **Compose the record into an entity.** The raw row, the resolved status
///    and the local overlay meet here; nothing above this layer knows those
///    are three different sources.
/// 3. **Narrow what Odoo could not.** Warranty buckets and the three overlay
///    statuses have no server-side field, so the query is widened and the
///    result filtered on the device — see [_narrow].
class AssetRepositoryImpl with RepositoryGuard implements AssetRepository {
  @override
  String get guardLabel => 'asset repository';

  AssetRepositoryImpl({
    required AssetRemoteDataSource remote,
    required AssetStatusResolver statusResolver,
    required AssetStateStore states,
    required OdooChatterService chatter,
  }) : _remote = remote,
       _statusResolver = statusResolver,
       _states = states,
       _chatter = chatter;

  final AssetRemoteDataSource _remote;
  final AssetStatusResolver _statusResolver;
  final AssetStateStore _states;
  final OdooChatterService _chatter;

  /// Memoised for the process: whether this instance has a real status field.
  /// Probing it per row would be one `fields_get` per asset.
  bool? _hasNativeStatusField;

  final StreamController<int> _changes = StreamController<int>.broadcast();

  @override
  Stream<int> get changes => _changes.stream;

  /// Announces that [id] now reads differently on the server.
  void _announce(int id) {
    if (!_changes.isClosed) _changes.add(id);
  }

  @override
  ResultFuture<PaginatedResult<Asset>> getAssets(AssetQuery query) =>
      guard(() async {
        final page = await _remote.fetchPage(query);
        final assets = await _toEntities(page.records);

        final narrowed = _narrow(assets, query.filters);

        return PaginatedResult<Asset>(
          items: narrowed,
          totalCount: page.totalCount,
          request: query.page,
          // The server's own scan position, not the narrowed length — see
          // PaginatedResult.scannedCount.
          scannedCount: query.page.offset + page.records.length,
        );
      });

  @override
  ResultFuture<Asset> getAsset(int id) => guard(() async {
    final record = await _remote.fetchOne(id);
    if (record == null) {
      throw RecordNotFoundException(_remote.model, id);
    }
    return _toEntity(record);
  });

  @override
  ResultFuture<Asset?> findByScannedCode(String code) => guard(() async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    // An `asset://<id>` payload is one this app printed, so it addresses the
    // record directly (spec §12).
    final id = _assetIdFromQrPayload(trimmed);
    if (id != null) {
      final record = await _remote.fetchOne(id);
      return record == null ? null : await _toEntity(record);
    }

    // Anything else is a manufacturer barcode or a printed serial.
    final record = await _remote.findBySerial(trimmed);
    return record == null ? null : await _toEntity(record);
  });

  @override
  ResultFuture<Asset> createAsset(AssetDraft draft) => guard(() async {
    final values = AssetMapper.toWriteValues(
      draft,
      supported: await _remote.writableFields(),
      required: await _remote.requiredFields(),
    );
    final id = await _remote.create(values);
    _announce(id);
    return _requireAsset(id);
  });

  @override
  ResultFuture<Asset> updateAsset(AssetDraft draft) => guard(() async {
    final id = draft.id;
    if (id == null) {
      throw const InputValidationException('This asset has no identifier.');
    }
    final values = AssetMapper.toWriteValues(
      draft,
      supported: await _remote.writableFields(),
      required: await _remote.requiredFields(),
    );
    await _remote.update(id, values);
    _announce(id);
    return _requireAsset(id);
  });

  @override
  ResultFuture<void> deleteAsset(int id) => guard(() async {
    await _remote.delete(id);
    // Only the mirror needs clearing: the notes went down with the record,
    // and an id Odoo reissues comes back with a chatter of its own.
    await _states.clear(_remote.model, id);
    _announce(id);
  });

  @override
  ResultFuture<Asset> assign(AssignmentRequest request) => guard(() async {
    await _remote.update(
      request.assetId,
      AssetMapper.assignmentValues(
        employeeId: request.employeeId,
        assignedOn: request.assignedOn,
        supported: await _remote.writableFields(),
      ),
    );

    // Handing an asset over supersedes any Reserved marker it carried.
    await _states.clear(_remote.model, request.assetId);

    await _postNote(
      request.assetId,
      _AssetNote.assigned(
        employee: request.employeeName,
        on: request.assignedOn,
        notes: request.notes,
      ),
    );

    _announce(request.assetId);
    return _requireAsset(request.assetId);
  });

  @override
  ResultFuture<Asset> unassign(ReturnRequest request) => guard(() async {
    await _remote.update(
      request.assetId,
      AssetMapper.returnValues(
        supported: await _remote.writableFields(),
        required: await _remote.requiredFields(),
      ),
    );

    // A return can land the asset in a state Odoo cannot express (Damaged), so
    // the overlay is written *after* the assignment is cleared — otherwise the
    // still-present employee_id would outrank it on the next read.
    await _states.mirror(
      _remote.model,
      request.assetId,
      request.resultingStatus,
    );
    if (request.resultingStatus.isLocalOnly) {
      // The return note says "condition: Damaged", which reads as history —
      // it does not say what the asset *is* now, and it is not what
      // [AssetStateStore] parses. Without this a damaged return came back as
      // Available on every device but the one that recorded it.
      await _postNote(
        request.assetId,
        AssetNoteVocabulary.statusNote(request.resultingStatus),
      );
    }

    await _attachPhotos(request.assetId, request.photoPaths);

    await _postNote(
      request.assetId,
      _AssetNote.returned(
        employee: request.employeeName,
        on: request.returnedOn,
        condition: request.condition,
        notes: request.notes,
      ),
    );

    _announce(request.assetId);
    return _requireAsset(request.assetId);
  });

  @override
  ResultFuture<Asset> setLocalStatus(int id, AssetStatus status) =>
      guard(() async {
        // The note *is* the write. These three states have no Odoo field, so
        // if this call fails the fact was recorded nowhere — which is why it
        // does not go through [_postNote]. Swallowing the error is right for a
        // note describing a write that already landed, and wrong for the only
        // write there is: it would report success and leave the state on this
        // handset alone, the failure this whole path was built to end.
        await _remote.postNote(id, AssetNoteVocabulary.statusNote(status));

        // Mirrored after, so an offline read and the screen behind this one
        // both answer immediately instead of waiting on a round trip.
        await _states.mirror(_remote.model, id, status);
        _announce(id);

        return _requireAsset(id);
      });

  @override
  ResultFuture<AssetHistory> history(int id) => guard(() async {
    // Both reads are independent, so they go out together: the history screen
    // is a back-navigation away from a detail the user is already looking at,
    // and two sequential round trips is what makes that feel like a wait.
    final (entries, asset) = await (
      _chatter.history(model: _remote.model, id: id),
      _remote.fetchOne(id),
    ).wait;

    return AssetHistory(
      entries: <AssetHistoryEntry>[
        for (final entry in entries)
          AssetHistoryEntry(
            id: entry.id,
            kind: AssetNoteVocabulary.classify(entry.body),
            summary: entry.body,
            occurredAt: entry.postedAt,
            author: entry.author,
          ),
      ],
      registeredOn: asset?.readDate(EquipmentFields.createDate),
    );
  });

  @override
  ResultFuture<AssetPermissions> permissions() => guard(() async {
    final results = await Future.wait(<Future<bool>>[
      _remote.can(_OdooOperation.create),
      _remote.can(_OdooOperation.write),
      _remote.can(_OdooOperation.unlink),
    ]);

    return AssetPermissions(
      canCreate: results[0],
      canEdit: results[1],
      canDelete: results[2],
    );
  });

  @override
  ResultFuture<List<String>> manufacturers() => guard(_remote.manufacturers);

  @override
  ResultFuture<List<OdooNameRef>> categories() => guard(_remote.categories);

  @override
  Future<void> invalidateCache() async {
    _hasNativeStatusField = null;
  }

  /// Closes the change stream. Called from `resetDependencies` in tests.
  Future<void> dispose() => _changes.close();

  // ── Composition ──────────────────────────────────────────────────────────

  Future<Asset> _requireAsset(int id) async {
    final record = await _remote.fetchOne(id);
    if (record == null) throw RecordNotFoundException(_remote.model, id);
    return _toEntity(record);
  }

  Future<Asset> _toEntity(OdooRecord record) async {
    final hasNative = await _nativeStatusField();
    final overlay = await _states.read(_remote.model, record['id'] as int);

    return AssetMapper.toEntity(
      record,
      status: _statusResolver.resolve(
        record: record,
        hasNativeField: hasNative,
        overlay: overlay,
      ),
    );
  }

  /// Maps a whole page, reading the overlay once for every id rather than
  /// once per row.
  Future<List<Asset>> _toEntities(OdooRecords records) async {
    if (records.isEmpty) return const <Asset>[];

    final hasNative = await _nativeStatusField();
    final ids = records
        .map((r) => r['id'])
        .whereType<int>()
        .toList(growable: false);
    final overlays = await _states.readAll(_remote.model, ids);

    return records
        .map(
          (record) => AssetMapper.toEntity(
            record,
            status: _statusResolver.resolve(
              record: record,
              hasNativeField: hasNative,
              overlay: overlays[record['id']],
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> _nativeStatusField() async => _hasNativeStatusField ??=
      await _statusResolver.hasNativeStatusField(_remote.model);

  /// Applies the filters Odoo could not evaluate.
  ///
  /// Only ever *removes* rows, so a filter the server already handled is a
  /// no-op here rather than a second, disagreeing implementation.
  List<Asset> _narrow(List<Asset> assets, AssetFilters filters) {
    var result = assets;

    if (filters.statuses.isNotEmpty) {
      result = result
          .where((a) => filters.statuses.contains(a.status))
          .toList(growable: false);
    }

    if (filters.warrantyStates.isNotEmpty) {
      result = result
          .where((a) => filters.warrantyStates.contains(a.warranty.state))
          .toList(growable: false);
    }

    return result;
  }

  /// Uploads the return photos as `ir.attachment` records.
  ///
  /// Each is sent individually and failures are per-file: one unreadable photo
  /// must not cost the user a return they have already confirmed, and the note
  /// and the status change have both already landed.
  Future<void> _attachPhotos(int id, List<String> paths) async {
    for (final path in paths.take(ReturnRequest.maxPhotos)) {
      try {
        final file = File(path);
        if (!file.existsSync()) continue;

        await _remote.attach(
          id: id,
          filename: _basename(path),
          base64Data: base64Encode(await file.readAsBytes()),
        );
      } on Object catch (error) {
        AppLogger.warn('Return photo upload failed for $path — $error');
      }
    }
  }

  Future<void> _postNote(int id, String body) async {
    try {
      await _remote.postNote(id, body);
    } on AppException catch (error) {
      // The record change already succeeded. Losing the audit note is worth
      // reporting to diagnostics, but not worth telling the user their
      // assignment failed when it did not.
      AppLogger.warn(
        'Chatter note failed for ${_remote.model}:$id — ${error.message}',
      );
    }
  }

  /// The file name from a path, for the attachment's display name.
  ///
  /// Split by hand rather than through `package:path`: the only thing needed
  /// is the segment after the last separator, and both separators are handled
  /// so a Windows-style path from a desktop run does not become one long name.
  static String _basename(String path) {
    final cut = path.lastIndexOf(RegExp(r'[/\\]'));
    final name = cut < 0 ? path : path.substring(cut + 1);
    return name.isEmpty ? path : name;
  }

  /// Reads the id out of an `asset://<id>` payload, or null for anything else.
  static int? _assetIdFromQrPayload(String code) {
    const prefix = '${AppConstants.qrScheme}://';
    if (!code.startsWith(prefix)) return null;
    return int.tryParse(code.substring(prefix.length).trim());
  }
}

/// Odoo's ACL operation names.
abstract final class _OdooOperation {
  static const String create = 'create';
  static const String write = 'write';
  static const String unlink = 'unlink';

  const _OdooOperation._();
}

/// The chatter notes the app writes.
///
/// Deliberately plain English and deliberately *not* localized: these are
/// written into Odoo, where they are read by whoever opens the record in the
/// web client — a colleague whose Odoo language has nothing to do with the
/// language this phone is set to. Translating them would make the audit trail
/// depend on who happened to press the button.
///
/// Deliberately plain **text**, too. `message_post` over XML-RPC escapes an
/// HTML body and wraps it in its own paragraph, so a note sent as
/// `<p>Assigned…</p>` shows up in the chatter as the literal characters
/// `<p>Assigned…</p>`. Sending text and letting Odoo do the wrapping is the
/// only shape that reads correctly in the web client.
abstract final class _AssetNote {
  static String assigned({
    required String employee,
    required DateTime on,
    String? notes,
  }) => AssetNoteVocabulary.compose(
    '${AssetNoteVocabulary.assignedPrefix} $employee on ${_day(on)}.',
    notes,
  );

  static String returned({
    String? employee,
    required DateTime on,
    required ReturnCondition condition,
    String? notes,
  }) => AssetNoteVocabulary.compose(
    '${AssetNoteVocabulary.returnedPrefix}'
    '${employee == null ? '' : ' by $employee'} on ${_day(on)} '
    '— condition: ${_conditionLabel(condition)}.',
    notes,
  );

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _conditionLabel(ReturnCondition condition) =>
      switch (condition) {
        ReturnCondition.good => 'Good',
        ReturnCondition.minorDamage => 'Minor damage',
        ReturnCondition.damaged => 'Damaged',
        ReturnCondition.needsMaintenance => 'Needs maintenance',
      };

  const _AssetNote._();
}
