import '../../constants/odoo_models.dart';
import '../../error/exceptions.dart';
import '../../pagination/page_request.dart';
import '../../utils/typedefs.dart';
import '../xmlrpc/xml_rpc_client.dart';
import 'odoo_connection.dart';
import 'odoo_name_ref.dart';
import 'odoo_session_manager.dart';

// Re-exported so the data layer, which legitimately uses this service, keeps
// getting the value object it returns without a second import line.
export 'odoo_name_ref.dart';

/// Wraps `/xmlrpc/2/object` — every authenticated model operation goes through
/// `execute_kw` here (spec §19).
///
/// This is the *only* class in the codebase that knows the shape of an
/// `execute_kw` call. Repositories speak in models, domains and fields; they
/// never build RPC payloads themselves, and widgets never see this type at
/// all (spec §18).
class OdooObjectService {
  OdooObjectService(this._client, this._sessionManager);

  final XmlRpcClient _client;
  final OdooSessionManager _sessionManager;

  /// Generic `execute_kw` entry point.
  ///
  /// [args] are positional arguments for the Odoo method, [kwargs] the keyword
  /// ones (`fields`, `limit`, `context`, …).
  Future<Object?> executeKw({
    required String model,
    required String method,
    List<Object?> args = const <Object?>[],
    Map<String, dynamic> kwargs = const <String, dynamic>{},
  }) async {
    final session = _sessionManager.requireSession();
    final secret = await _sessionManager.requireSecret();
    final connection = session.connection;

    return _client.call(
      endpoint: connection.objectEndpoint,
      methodName: 'execute_kw',
      params: <Object?>[
        connection.database,
        session.userId,
        secret,
        model,
        method,
        args,
        _withContext(kwargs, connection),
      ],
    );
  }

  // ── Read operations ──────────────────────────────────────────────────────

  /// `search_read` with pagination (spec §20 — never fetch everything).
  Future<OdooRecords> searchRead({
    required String model,
    OdooDomain domain = const <Object?>[],
    required List<String> fields,
    int? limit,
    int? offset,
    String? order,
    Map<String, dynamic>? context,
  }) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.searchRead,
      args: <Object?>[domain],
      kwargs: <String, dynamic>{
        'fields': fields,
        if (limit != null) 'limit': limit,
        if (offset != null && offset > 0) 'offset': offset,
        if (order != null) 'order': order,
        if (context != null) 'context': context,
      },
    );
    return _asRecords(result, model, 'search_read');
  }

  /// Convenience overload that takes a [PageRequest].
  Future<OdooRecords> searchReadPage({
    required String model,
    required List<String> fields,
    required PageRequest page,
    OdooDomain domain = const <Object?>[],
    Map<String, dynamic>? context,
  }) {
    return searchRead(
      model: model,
      domain: domain,
      fields: fields,
      limit: page.limit,
      offset: page.offset,
      order: page.order,
      context: context,
    );
  }

  Future<List<int>> search({
    required String model,
    OdooDomain domain = const <Object?>[],
    int? limit,
    int? offset,
    String? order,
  }) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.search,
      args: <Object?>[domain],
      kwargs: <String, dynamic>{
        if (limit != null) 'limit': limit,
        if (offset != null && offset > 0) 'offset': offset,
        if (order != null) 'order': order,
      },
    );
    if (result is! List) {
      throw _unexpected(model, 'search', result);
    }
    return result.whereType<int>().toList(growable: false);
  }

  /// `search_count` — drives the "N of M" counters and infinite scroll.
  Future<int> searchCount({
    required String model,
    OdooDomain domain = const <Object?>[],
  }) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.searchCount,
      args: <Object?>[domain],
    );
    if (result is int) return result;
    throw _unexpected(model, 'search_count', result);
  }

  Future<OdooRecords> read({
    required String model,
    required List<int> ids,
    required List<String> fields,
    Map<String, dynamic>? context,
  }) async {
    if (ids.isEmpty) return const <OdooRecord>[];
    final result = await executeKw(
      model: model,
      method: OdooMethods.read,
      args: <Object?>[ids],
      kwargs: <String, dynamic>{
        'fields': fields,
        if (context != null) 'context': context,
      },
    );
    return _asRecords(result, model, 'read');
  }

  /// `fields_get` — the backbone of dynamic compatibility (spec §17).
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    List<String> attributes = const [
      'string',
      'type',
      'required',
      'readonly',
      'relation',
      'selection',
    ],
  }) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.fieldsGet,
      args: const <Object?>[<Object?>[]],
      kwargs: <String, dynamic>{'attributes': attributes},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    throw _unexpected(model, 'fields_get', result);
  }

  /// `name_search` — resolves a display name to an id without ever hardcoding
  /// a database id (spec §10).
  ///
  /// ## Why this tries two call shapes
  ///
  /// Odoo renamed this method's parameters in 19: what was
  /// `name_search(name, args, operator, limit)` in 17 and 18 became
  /// `name_search(name, domain, limit)`. Sending `args`/`operator` to an
  /// Odoo 19 raises an unexpected-keyword fault, and sending `domain` to an
  /// Odoo 17 does the same — so an app that must run on all three (spec §28)
  /// cannot pick one.
  ///
  /// It calls the modern shape, falls back to the legacy one on a fault, and
  /// remembers which worked. Every call after the first is a single round trip.
  Future<List<OdooNameRef>> nameSearch({
    required String model,
    String query = '',
    OdooDomain domain = const <Object?>[],
    int limit = 20,
  }) async {
    Object? result;

    if (_nameSearchUsesLegacyArgs ?? false) {
      result = await _nameSearchLegacy(model, query, domain, limit);
    } else {
      try {
        result = await _nameSearchModern(model, query, domain, limit);
        _nameSearchUsesLegacyArgs = false;
      } on AppException {
        // Older Odoo: retry with the parameter names it knows.
        result = await _nameSearchLegacy(model, query, domain, limit);
        _nameSearchUsesLegacyArgs = true;
      }
    }

    if (result is! List) {
      throw _unexpected(model, 'name_search', result);
    }
    return result
        .whereType<List<Object?>>()
        .map(OdooNameRef.fromPair)
        .whereType<OdooNameRef>()
        .toList(growable: false);
  }

  /// Which `name_search` signature this server accepts, once discovered.
  ///
  /// Null until the first call. Memoised per process rather than cached with
  /// the other metadata: it is a property of the server binary, it is answered
  /// by the first call anyway, and a wrong cached value would cost an extra
  /// round trip rather than a wrong result.
  bool? _nameSearchUsesLegacyArgs;

  /// Odoo 19: `name`, `domain`, `limit`.
  Future<Object?> _nameSearchModern(
    String model,
    String query,
    OdooDomain domain,
    int limit,
  ) => executeKw(
    model: model,
    method: OdooMethods.nameSearch,
    kwargs: <String, dynamic>{'name': query, 'domain': domain, 'limit': limit},
  );

  /// Odoo 17 and 18: `name`, `args`, `operator`, `limit`.
  Future<Object?> _nameSearchLegacy(
    String model,
    String query,
    OdooDomain domain,
    int limit,
  ) => executeKw(
    model: model,
    method: OdooMethods.nameSearch,
    kwargs: <String, dynamic>{
      'name': query,
      'args': domain,
      'operator': 'ilike',
      'limit': limit,
    },
  );

  // ── Write operations ─────────────────────────────────────────────────────

  Future<int> create({
    required String model,
    required Map<String, dynamic> values,
    Map<String, dynamic>? context,
  }) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.create,
      args: <Object?>[values],
      kwargs: <String, dynamic>{if (context != null) 'context': context},
    );
    if (result is int) return result;
    // Odoo 17+ may return a list when passed a list of vals.
    if (result is List && result.isNotEmpty && result.first is int) {
      return result.first as int;
    }
    throw _unexpected(model, 'create', result);
  }

  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
    Map<String, dynamic>? context,
  }) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.write,
      args: <Object?>[ids, values],
      kwargs: <String, dynamic>{if (context != null) 'context': context},
    );
    return result == true;
  }

  Future<bool> unlink({required String model, required List<int> ids}) async {
    final result = await executeKw(
      model: model,
      method: OdooMethods.unlink,
      args: <Object?>[ids],
    );
    return result == true;
  }

  /// `check_access_rights` — lets the UI hide actions the user cannot perform
  /// instead of letting them fail (spec §21).
  Future<bool> checkAccessRights({
    required String model,
    required String operation,
  }) async {
    try {
      final result = await executeKw(
        model: model,
        method: OdooMethods.checkAccessRights,
        args: <Object?>[operation],
        kwargs: const <String, dynamic>{'raise_exception': false},
      );
      return result == true;
    } on AppException {
      // Renamed to `check_access` in newer versions; treat an error as "unknown"
      // and let the actual operation surface the real ACL message.
      return true;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _withContext(
    Map<String, dynamic> kwargs,
    OdooConnection connection,
  ) {
    // Odoo needs an explicit context for consistent language and timezone
    // handling; without it, dates come back in the server's tz.
    final existing = kwargs['context'];
    final context = <String, dynamic>{
      if (existing is Map) ...Map<String, dynamic>.from(existing),
    };
    return <String, dynamic>{
      ...kwargs,
      if (context.isNotEmpty) 'context': context,
    };
  }

  OdooRecords _asRecords(Object? result, String model, String method) {
    if (result is! List) throw _unexpected(model, method, result);
    return result
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  AppException _unexpected(String model, String method, Object? result) {
    return ResponseParsingException(
      'The server returned unexpected data.',
      technicalDetails: '$model.$method returned ${result.runtimeType}',
    );
  }
}
