import 'package:equatable/equatable.dart';

import '../../constants/app_constants.dart';
import '../../constants/odoo_models.dart';
import '../../constants/storage_keys.dart';
import '../../error/exceptions.dart';
import '../../storage/cache/cache_store.dart';
import '../../utils/logger.dart';
import 'odoo_object_service.dart';

/// Runtime discovery of what this particular Odoo instance can do (spec §17).
///
/// Every optional feature asks this service before rendering. A missing model
/// or field therefore hides a feature instead of throwing — acceptance
/// criterion 10.
///
/// Results are memoised in RAM for the process lifetime and persisted with a
/// TTL so a cold start does not re-probe the whole schema.
class OdooCapabilityService {
  OdooCapabilityService(this._objectService, this._cache);

  final OdooObjectService _objectService;
  final CacheStore _cache;

  final Map<String, bool> _modelCache = {};
  final Map<String, Set<String>> _fieldCache = {};
  final Map<String, Set<String>> _requiredCache = {};

  /// True when [model] is installed on the instance.
  ///
  /// Uses `ir.model` rather than a probe call, because a failing probe cannot
  /// distinguish "not installed" from "no read access".
  Future<bool> modelExists(String model) async {
    final memo = _modelCache[model];
    if (memo != null) return memo;

    final cached = await _cache.get<bool>(CacheBoxes.metadata, 'model:$model');
    if (cached != null && cached.isFresh(AppConstants.metadataTtl)) {
      return _modelCache[model] = cached.value;
    }

    try {
      final count = await _objectService.searchCount(
        model: OdooModels.irModel,
        domain: <Object?>[
          <Object?>['model', '=', model],
        ],
      );
      final exists = count > 0;
      _modelCache[model] = exists;
      await _cache.put(CacheBoxes.metadata, 'model:$model', exists);
      return exists;
    } on AppException catch (e) {
      // Cannot read ir.model (unusual ACL setup). Assume unavailable rather
      // than crashing; the feature degrades quietly.
      AppLogger.warn('Capability probe failed for $model: ${e.message}');
      return _modelCache[model] = false;
    }
  }

  /// Every readable field name on [model].
  Future<Set<String>> getFields(String model) async {
    final memo = _fieldCache[model];
    if (memo != null) return memo;

    final cached = await _cache.get<List<dynamic>>(
      CacheBoxes.metadata,
      'fields:$model',
    );
    if (cached != null && cached.isFresh(AppConstants.metadataTtl)) {
      return _fieldCache[model] = cached.value.map((e) => '$e').toSet();
    }

    try {
      final descriptor = await _objectService.fieldsGet(model: model);
      final fields = descriptor.keys.toSet();
      _fieldCache[model] = fields;
      await _cache.put(
        CacheBoxes.metadata,
        'fields:$model',
        fields.toList(growable: false),
      );
      return fields;
    } on AppException catch (e) {
      AppLogger.warn('fields_get failed for $model: ${e.message}');
      return _fieldCache[model] = <String>{};
    }
  }

  /// Fields [model] marks `required`.
  ///
  /// Needed because a required field cannot be *cleared*: sending Odoo's
  /// "empty" sentinel `false` for one overrides the server-side default and
  /// then fails its own mandatory-field constraint. Stock Odoo 19 marks
  /// `maintenance.equipment.effective_date` required, so an asset created with
  /// no purchase date is exactly that case.
  Future<Set<String>> requiredFields(String model) async {
    final memo = _requiredCache[model];
    if (memo != null) return memo;

    final cached = await _cache.get<List<dynamic>>(
      CacheBoxes.metadata,
      'required:$model',
    );
    if (cached != null && cached.isFresh(AppConstants.metadataTtl)) {
      return _requiredCache[model] = cached.value.map((e) => '$e').toSet();
    }

    try {
      final descriptor = await _objectService.fieldsGet(model: model);
      final required = <String>{
        for (final entry in descriptor.entries)
          if (entry.value is Map && (entry.value as Map)['required'] == true)
            entry.key,
      };
      _requiredCache[model] = required;
      await _cache.put(
        CacheBoxes.metadata,
        'required:$model',
        required.toList(growable: false),
      );
      return required;
    } on AppException catch (e) {
      // Unknown means "assume nothing is required", which is the permissive
      // reading: the write is attempted and Odoo gives the real answer.
      AppLogger.warn('required fields unavailable for $model: ${e.message}');
      return _requiredCache[model] = <String>{};
    }
  }

  Future<bool> fieldExists(String model, String field) async {
    final fields = await getFields(model);
    return fields.contains(field);
  }

  /// Narrows a wish-list of fields to those the instance actually has.
  ///
  /// Every repository funnels its read set through this before querying, which
  /// is what makes the app work unchanged across Odoo 17, 18 and 19 (spec §28).
  Future<List<String>> supportedFields(
    String model,
    List<String> wanted,
  ) async {
    final available = await getFields(model);
    if (available.isEmpty) return const <String>['id'];
    final supported = wanted.where(available.contains).toList(growable: false);
    return supported.isEmpty ? const <String>['id'] : supported;
  }

  /// Resolves the first model in [candidates] that exists.
  ///
  /// Used for models Odoo renamed between versions, such as
  /// `stock.production.lot` → `stock.lot`.
  Future<String?> resolveFirstAvailable(List<String> candidates) async {
    for (final candidate in candidates) {
      if (await modelExists(candidate)) return candidate;
    }
    return null;
  }

  /// Probes everything the app cares about in one pass, at login.
  Future<OdooCapabilities> probeAll() async {
    final hasMaintenance = await modelExists(OdooModels.maintenanceEquipment);
    final hasMaintenanceRequests =
        hasMaintenance && await modelExists(OdooModels.maintenanceRequest);
    final hasHr = await modelExists(OdooModels.hrEmployee);
    final hasDepartments = hasHr && await modelExists(OdooModels.hrDepartment);
    final hasInventory = await modelExists(OdooModels.productProduct);
    final lotModel = await resolveFirstAvailable(const [
      OdooModels.stockLot,
      OdooModels.stockProductionLotLegacy,
    ]);
    final hasActivityLog = await modelExists(OdooModels.mailMessage);

    final capabilities = OdooCapabilities(
      hasMaintenance: hasMaintenance,
      hasMaintenanceRequests: hasMaintenanceRequests,
      hasHrEmployees: hasHr,
      hasDepartments: hasDepartments,
      hasInventory: hasInventory,
      lotModel: lotModel,
      hasActivityLog: hasActivityLog,
    );

    AppLogger.info('Odoo capabilities: $capabilities');
    return capabilities;
  }

  /// Drops every memoised and persisted probe. Backs Settings → "Refresh Odoo
  /// metadata" (spec §23).
  Future<void> invalidate() async {
    _modelCache.clear();
    _fieldCache.clear();
    _requiredCache.clear();
    await _cache.clearBox(CacheBoxes.metadata);
  }

  /// Convenience guard for repositories: throws a typed, catchable error when
  /// an optional model is missing.
  Future<void> requireModel(String model) async {
    if (!await modelExists(model)) {
      throw ModelNotAvailableException(model);
    }
  }
}

/// Snapshot of what the connected instance supports.
///
/// Exposed to the UI through a Cubit so screens can hide unsupported tabs
/// rather than showing an error after the fact.
class OdooCapabilities extends Equatable {
  const OdooCapabilities({
    this.hasMaintenance = false,
    this.hasMaintenanceRequests = false,
    this.hasHrEmployees = false,
    this.hasDepartments = false,
    this.hasInventory = false,
    this.lotModel,
    this.hasActivityLog = false,
  });

  const OdooCapabilities.unknown() : this();

  final bool hasMaintenance;
  final bool hasMaintenanceRequests;
  final bool hasHrEmployees;
  final bool hasDepartments;
  final bool hasInventory;
  final String? lotModel;
  final bool hasActivityLog;

  /// Which standard model backs an "asset" on this instance.
  ///
  /// Preference order is Maintenance (richest fit: serial, warranty, employee,
  /// vendor, cost) then Inventory serials. Neither present means the instance
  /// cannot host assets without configuration, and the UI says so plainly.
  AssetSource get assetSource {
    if (hasMaintenance) return AssetSource.maintenanceEquipment;
    if (lotModel != null) return AssetSource.stockLot;
    if (hasInventory) return AssetSource.productProduct;
    return AssetSource.none;
  }

  bool get canAssignToEmployees => hasHrEmployees;

  @override
  List<Object?> get props => [
    hasMaintenance,
    hasMaintenanceRequests,
    hasHrEmployees,
    hasDepartments,
    hasInventory,
    lotModel,
    hasActivityLog,
  ];

  @override
  String toString() =>
      'maintenance=$hasMaintenance hr=$hasHrEmployees '
      'inventory=$hasInventory lot=$lotModel source=${assetSource.name}';
}

/// The standard model chosen to store assets on this instance.
enum AssetSource {
  maintenanceEquipment,
  stockLot,
  productProduct,
  none;

  String? get modelName => switch (this) {
    AssetSource.maintenanceEquipment => OdooModels.maintenanceEquipment,
    AssetSource.stockLot => OdooModels.stockLot,
    AssetSource.productProduct => OdooModels.productProduct,
    AssetSource.none => null,
  };
}
