import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Loads every dashboard figure in one pass (spec §4).
class GetDashboardSummary extends UseCaseWithoutParams<DashboardSummary> {
  const GetDashboardSummary(this._repository);

  final DashboardRepository _repository;

  @override
  ResultFuture<DashboardSummary> call() => _repository.getSummary();
}

/// The dashboard's ViewModel.
///
/// A [SimpleViewState] rather than a bespoke state class: the screen loads one
/// value and renders it, so a hand-written state would add nothing but a file.
class DashboardCubit extends Cubit<SimpleViewState<DashboardSummary>> {
  DashboardCubit(this._getSummary)
    : super(const SimpleViewState<DashboardSummary>());

  final GetDashboardSummary _getSummary;

  Future<void> load({bool refresh = false}) async {
    emit(refresh ? state.refreshing() : state.loading());

    final result = await _getSummary();
    if (isClosed) return;

    emit(result.fold(state.failed, state.success));
  }
}
