import '../../../../core/pagination/page_request.dart';
import '../../../../core/pagination/paginated_result.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/maintenance_request.dart';

/// What the app can do with maintenance requests (spec §16).
abstract interface class MaintenanceRepository {
  ResultFuture<PaginatedResult<MaintenanceRequest>> getRequests({
    MaintenanceFilters filters,
    PageRequest page,
  });

  ResultFuture<MaintenanceRequest> getRequest(int id);

  /// Opens a request against an asset — reached from the asset detail screen
  /// and from a return recorded as damaged (spec §8).
  ResultFuture<MaintenanceRequest> createRequest({
    required int equipmentId,
    required String name,
    required MaintenanceType type,
    MaintenancePriority priority,
    String? description,
    DateTime? scheduledFor,
  });
}
