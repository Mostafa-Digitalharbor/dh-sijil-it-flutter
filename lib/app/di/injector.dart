import 'package:get_it/get_it.dart';

import '../../core/network/connectivity/network_info.dart';
import '../../core/network/odoo/odoo_attachment_service.dart';
import '../../core/network/odoo/odoo_auth_service.dart';
import '../../core/network/odoo/odoo_capability_service.dart';
import '../../core/network/odoo/odoo_chatter_service.dart';
import '../../core/network/odoo/odoo_object_service.dart';
import '../../core/network/odoo/odoo_session_manager.dart';
import '../../core/network/xmlrpc/xml_rpc_client.dart';
import '../../core/security/credential_vault.dart';
import '../../core/services/photo_picker.dart';
import '../../core/storage/cache/cache_store.dart';
import '../../core/storage/cache/hive_cache_store.dart';
import '../../core/storage/preferences/app_preferences.dart';
import '../../features/assets/data/datasources/asset_remote_data_source.dart';
import '../../features/assets/data/repositories/asset_repository_impl.dart';
import '../../features/assets/data/services/asset_state_store.dart';
import '../../features/assets/data/services/asset_status_resolver.dart';
import '../../features/assets/data/services/local_asset_state_store.dart';
import '../../features/assets/domain/repositories/asset_repository.dart';
import '../../features/assets/domain/usecases/asset_usecases.dart';
import '../../features/assets/presentation/cubit/asset_detail_cubit.dart';
import '../../features/assets/presentation/cubit/asset_form_cubit.dart';
import '../../features/assets/presentation/cubit/asset_history_cubit.dart';
import '../../features/assets/presentation/cubit/asset_list_cubit.dart';
import '../../features/assignment/presentation/cubit/assign_asset_cubit.dart';
import '../../features/assignment/presentation/cubit/return_asset_cubit.dart';
import '../../features/attachments/data/repositories/attachment_repository_impl.dart';
import '../../features/attachments/domain/repositories/attachment_repository.dart';
import '../../features/attachments/domain/usecases/attachment_usecases.dart';
import '../../features/attachments/presentation/cubit/photo_cubit.dart';
import '../../features/audit/data/repositories/audit_repository_impl.dart';
import '../../features/audit/domain/repositories/audit_repository.dart';
import '../../features/audit/domain/usecases/audit_usecases.dart';
import '../../features/audit/presentation/cubit/audit_cubit.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/domain/usecases/employee_usecases.dart';
import '../../features/employees/presentation/cubit/employee_detail_cubit.dart';
import '../../features/employees/presentation/cubit/employee_list_cubit.dart';
import '../../features/handover/data/repositories/handover_repository_impl.dart';
import '../../features/handover/domain/repositories/handover_repository.dart';
import '../../features/handover/domain/usecases/handover_usecases.dart';
import '../../features/handover/presentation/cubit/handover_cubit.dart';
import '../../features/maintenance/data/repositories/maintenance_repository_impl.dart';
import '../../features/maintenance/domain/repositories/maintenance_repository.dart';
import '../../features/maintenance/presentation/cubit/maintenance_cubit.dart';
import '../../features/scanner/presentation/cubit/scanner_cubit.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';

/// Service Locator for the whole app.
///
/// Registration is written by hand rather than generated: the graph is small,
/// the wiring stays readable, and there is no build_runner step to keep green
/// in CI. Everything is registered against its *interface* where one exists,
/// so a test can swap any layer for a fake.
final GetIt sl = GetIt.instance;

/// Wires the object graph. Called once from `bootstrap()` before `runApp`.
///
/// Registration order mirrors the dependency direction of the architecture:
/// storage and transport first, then Odoo services, then repositories, use
/// cases and finally the Cubits that consume them.
Future<void> configureDependencies() async {
  await _registerPlatform();
  _registerTransport();
  registerAppGraph();
}

/// Everything above the platform: Odoo services, repositories, use cases and
/// Cubits.
///
/// Split out so the widget-test harness can register in-memory replacements for
/// the three platform-bound pieces — the keystore, Hive and connectivity — and
/// then build **this exact graph** on top. A test that wires its own
/// repositories is a test of a second implementation nobody ships; this way a
/// widget test exercises the same objects `bootstrap()` does.
///
/// Requires [CredentialVault], [CacheStore], [AppPreferences], [NetworkInfo]
/// and [XmlRpcClient] to be registered already.
void registerAppGraph() {
  _registerOdooServices();
  _registerRepositories();
  _registerUseCases();
  _registerCubits();
}

// ── Layer 0: platform & storage ────────────────────────────────────────────
Future<void> _registerPlatform() async {
  sl.registerLazySingleton<CredentialVault>(CredentialVault.createDefault);

  final cacheStore = HiveCacheStore(sl<CredentialVault>());
  await cacheStore.init();
  sl.registerSingleton<CacheStore>(cacheStore);

  final preferences = await AppPreferences.create();
  sl.registerSingleton<AppPreferences>(preferences);

  sl.registerLazySingleton<NetworkInfo>(ConnectivityNetworkInfo.createDefault);
}

// ── Layer 1: transport ─────────────────────────────────────────────────────
void _registerTransport() {
  sl.registerLazySingleton<XmlRpcClient>(DioXmlRpcClient.createDefault);
}

// ── Layer 2: Odoo services ─────────────────────────────────────────────────
void _registerOdooServices() {
  sl.registerLazySingleton<OdooSessionManager>(
    () => OdooSessionManager(sl<CredentialVault>()),
  );
  sl.registerLazySingleton<OdooAuthService>(
    () => OdooAuthService(sl<XmlRpcClient>()),
  );
  sl.registerLazySingleton<OdooObjectService>(
    () => OdooObjectService(sl<XmlRpcClient>(), sl<OdooSessionManager>()),
  );
  sl.registerLazySingleton<OdooCapabilityService>(
    () => OdooCapabilityService(sl<OdooObjectService>(), sl<CacheStore>()),
  );
  // Model-agnostic: assets and maintenance requests both hang files and
  // chatter off records, and neither owns the behaviour.
  sl.registerLazySingleton<OdooAttachmentService>(
    () => OdooAttachmentService(sl<OdooObjectService>()),
  );
  sl.registerLazySingleton<OdooChatterService>(
    () => OdooChatterService(sl<OdooObjectService>()),
  );
  sl.registerLazySingleton<PhotoPicker>(ImagePickerAdapter.new);
}

// ── Layer 3: repositories ──────────────────────────────────────────────────
//
// Singletons: they hold no per-screen state, and the asset repository memoises
// one capability probe that would otherwise repeat on every screen.
void _registerRepositories() {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      authService: sl<OdooAuthService>(),
      objectService: sl<OdooObjectService>(),
      sessionManager: sl<OdooSessionManager>(),
      capabilityService: sl<OdooCapabilityService>(),
      vault: sl<CredentialVault>(),
      preferences: sl<AppPreferences>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<LocalAssetStateStore>(
    () => LocalAssetStateStore(sl<CacheStore>()),
  );
  sl.registerLazySingleton<AssetStateStore>(
    () => AssetStateStore(
      mirror: sl<LocalAssetStateStore>(),
      chatter: sl<OdooChatterService>(),
    ),
  );
  sl.registerLazySingleton<AssetStatusResolver>(
    () => AssetStatusResolver(sl<OdooCapabilityService>()),
  );

  // The strategy that decides which standard model backs an asset. Registered
  // against the interface so adding a `stock.lot` source later is one line
  // here rather than an edit to every caller.
  sl.registerLazySingleton<AssetRemoteDataSource>(
    () => MaintenanceEquipmentDataSource(
      sl<OdooObjectService>(),
      sl<OdooCapabilityService>(),
    ),
  );

  sl.registerLazySingleton<AssetRepository>(
    () => AssetRepositoryImpl(
      remote: sl<AssetRemoteDataSource>(),
      statusResolver: sl<AssetStatusResolver>(),
      states: sl<AssetStateStore>(),
      chatter: sl<OdooChatterService>(),
    ),
  );

  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(
      odoo: sl<OdooObjectService>(),
      capabilities: sl<OdooCapabilityService>(),
    ),
  );

  sl.registerLazySingleton<AttachmentRepository>(
    () => AttachmentRepositoryImpl(sl<OdooAttachmentService>()),
  );
  sl.registerLazySingleton<MaintenanceRepository>(
    () => MaintenanceRepositoryImpl(
      odoo: sl<OdooObjectService>(),
      capabilities: sl<OdooCapabilityService>(),
    ),
  );

  sl.registerLazySingleton<AuditRepository>(
    () => AuditRepositoryImpl(
      assets: sl<AssetRepository>(),
      odoo: sl<OdooObjectService>(),
    ),
  );

  sl.registerLazySingleton<HandoverRepository>(
    () => HandoverRepositoryImpl(
      assets: sl<AssetRepository>(),
      attachments: sl<AttachmentRepository>(),
      model: sl<AssetRemoteDataSource>().model,
    ),
  );

  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      odoo: sl<OdooObjectService>(),
      capabilities: sl<OdooCapabilityService>(),
      states: sl<AssetStateStore>(),
    ),
  );
}

// ── Layer 4: use cases ─────────────────────────────────────────────────────
//
// Stateless and const-constructible, so one instance each is plenty.
void _registerUseCases() {
  sl
    ..registerLazySingleton(() => GetAssetsPage(sl<AssetRepository>()))
    ..registerLazySingleton(() => GetAsset(sl<AssetRepository>()))
    ..registerLazySingleton(() => ResolveScannedCode(sl<AssetRepository>()))
    ..registerLazySingleton(() => CreateAsset(sl<AssetRepository>()))
    ..registerLazySingleton(() => UpdateAsset(sl<AssetRepository>()))
    ..registerLazySingleton(() => DeleteAsset(sl<AssetRepository>()))
    ..registerLazySingleton(() => AssignAsset(sl<AssetRepository>()))
    ..registerLazySingleton(() => ReturnAsset(sl<AssetRepository>()))
    ..registerLazySingleton(() => SetLocalAssetStatus(sl<AssetRepository>()))
    ..registerLazySingleton(() => GetAssetListOptions(sl<AssetRepository>()))
    ..registerLazySingleton(() => GetAssetHistory(sl<AssetRepository>()))
    ..registerLazySingleton(() => GetEmployeesPage(sl<EmployeeRepository>()))
    ..registerLazySingleton(() => GetEmployee(sl<EmployeeRepository>()))
    ..registerLazySingleton(() => SearchEmployees(sl<EmployeeRepository>()))
    ..registerLazySingleton(() => GetDepartments(sl<EmployeeRepository>()))
    ..registerLazySingleton(
      () => GetMaintenanceRequests(sl<MaintenanceRepository>()),
    )
    ..registerLazySingleton(
      () => GetMaintenanceRequest(sl<MaintenanceRepository>()),
    )
    ..registerLazySingleton(
      () => CreateMaintenanceRequest(sl<MaintenanceRepository>()),
    )
    ..registerLazySingleton(() => StartAudit(sl<AuditRepository>()))
    ..registerLazySingleton(() => CommitAudit(sl<AuditRepository>()))
    ..registerLazySingleton(() => SubmitHandover(sl<HandoverRepository>()))
    ..registerLazySingleton(
      () => GetDashboardSummary(sl<DashboardRepository>()),
    )
    ..registerLazySingleton(() => GetRecordPhotos(sl<AttachmentRepository>()))
    ..registerLazySingleton(() => LoadPhotoData(sl<AttachmentRepository>()))
    ..registerLazySingleton(() => AddRecordPhoto(sl<AttachmentRepository>()))
    ..registerLazySingleton(
      () => AddRecordPhotoBytes(sl<AttachmentRepository>()),
    )
    ..registerLazySingleton(
      () => RemoveRecordPhoto(sl<AttachmentRepository>()),
    );
}

// ── Layer 5: Cubits ────────────────────────────────────────────────────────
//
// Factories, not singletons: each visit to a screen gets a fresh ViewModel, so
// nothing leaks between two openings of the same page. `AuthCubit` is the one
// exception — it is the app-wide session and is provided once, above the
// router.
void _registerCubits() {
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));

  sl.registerFactory(() => AssetHistoryCubit(sl<GetAssetHistory>()));

  // Takes the record it belongs to as a parameter rather than being registered
  // per feature: an asset and a maintenance request differ only in the model
  // string, so one registration serves both screens.
  sl.registerFactoryParam<PhotoCubit, RecordRef, bool?>(
    (record, canEdit) => PhotoCubit(
      model: record.model,
      recordId: record.id,
      getPhotos: sl<GetRecordPhotos>(),
      loadData: sl<LoadPhotoData>(),
      addPhoto: sl<AddRecordPhoto>(),
      removePhoto: sl<RemoveRecordPhoto>(),
      picker: sl<PhotoPicker>(),
      canEdit: canEdit ?? true,
    ),
  );

  sl
    ..registerFactory(
      () => AssetListCubit(
        getAssets: sl<GetAssetsPage>(),
        getOptions: sl<GetAssetListOptions>(),
        getDepartments: sl<GetDepartments>(),
        repository: sl<AssetRepository>(),
      ),
    )
    ..registerFactory(
      () => AssetDetailCubit(
        getAsset: sl<GetAsset>(),
        setLocalStatus: sl<SetLocalAssetStatus>(),
        deleteAsset: sl<DeleteAsset>(),
        getOptions: sl<GetAssetListOptions>(),
        createRequest: sl<CreateMaintenanceRequest>(),
        getRequests: sl<GetMaintenanceRequests>(),
        repository: sl<AssetRepository>(),
      ),
    )
    ..registerFactory(
      () => AssetFormCubit(
        getAsset: sl<GetAsset>(),
        createAsset: sl<CreateAsset>(),
        updateAsset: sl<UpdateAsset>(),
        getOptions: sl<GetAssetListOptions>(),
      ),
    )
    ..registerFactory(
      () => AssignAssetCubit(
        getAsset: sl<GetAsset>(),
        searchEmployees: sl<SearchEmployees>(),
        assignAsset: sl<AssignAsset>(),
      ),
    )
    ..registerFactory(
      () => ReturnAssetCubit(
        getAsset: sl<GetAsset>(),
        returnAsset: sl<ReturnAsset>(),
      ),
    )
    ..registerFactory(
      () => EmployeeListCubit(
        getEmployees: sl<GetEmployeesPage>(),
        getDepartments: sl<GetDepartments>(),
      ),
    )
    ..registerFactory(
      () => EmployeeDetailCubit(
        getEmployee: sl<GetEmployee>(),
        getAssets: sl<GetAssetsPage>(),
      ),
    )
    ..registerFactory(() => MaintenanceListCubit(sl<GetMaintenanceRequests>()))
    ..registerFactory(() => MaintenanceDetailCubit(sl<GetMaintenanceRequest>()))
    ..registerFactory(() => DashboardCubit(sl<GetDashboardSummary>()))
    ..registerFactory(() => ScannerCubit(sl<ResolveScannedCode>()))
    ..registerFactory(
      () => AuditCubit(
        startAudit: sl<StartAudit>(),
        commitAudit: sl<CommitAudit>(),
        resolveCode: sl<ResolveScannedCode>(),
        listOptions: sl<GetAssetListOptions>(),
        departments: sl<GetDepartments>(),
      ),
    )
    ..registerFactory(
      () => HandoverCubit(
        searchEmployees: sl<SearchEmployees>(),
        getAssets: sl<GetAssetsPage>(),
        submitHandover: sl<SubmitHandover>(),
      ),
    )
    ..registerFactory(
      () => SettingsCubit(
        cache: sl<CacheStore>(),
        states: sl<AssetStateStore>(),
        capabilities: sl<OdooCapabilityService>(),
        preferences: sl<AppPreferences>(),
        auth: sl<AuthRepository>(),
      ),
    );
}

/// Tears the graph down. Used by integration tests between scenarios.
Future<void> resetDependencies() => sl.reset();
