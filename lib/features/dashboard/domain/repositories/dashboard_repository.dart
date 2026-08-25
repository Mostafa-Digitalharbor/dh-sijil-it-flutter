import '../../../../core/utils/typedefs.dart';
import '../entities/dashboard_summary.dart';

/// The dashboard's one question, asked of the data layer (spec §4).
abstract interface class DashboardRepository {
  /// Every figure the dashboard shows, gathered in one pass.
  ///
  /// A single method rather than one per tile: the screen is useless with half
  /// its numbers, so there is no state worth modelling where some arrived and
  /// others did not.
  ResultFuture<DashboardSummary> getSummary();
}
