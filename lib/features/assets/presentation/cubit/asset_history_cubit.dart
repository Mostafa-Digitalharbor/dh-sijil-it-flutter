import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/asset_history.dart';
import '../../domain/usecases/asset_usecases.dart';

/// ViewModel for one asset's service life.
class AssetHistoryCubit extends Cubit<SimpleViewState<AssetHistory>> {
  AssetHistoryCubit(this._getHistory)
    : super(const SimpleViewState<AssetHistory>());

  final GetAssetHistory _getHistory;

  int _assetId = 0;
  bool _isLoadingMore = false;

  /// Whether an older page is on its way. Drives the footer spinner.
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load(int assetId, {bool refresh = false}) async {
    _assetId = assetId;
    _isLoadingMore = false;
    emit(refresh ? state.refreshing() : state.loading());

    final result = await _getHistory(assetId);
    if (isClosed) return;

    emit(result.fold(state.failed, state.success));
  }

  /// Reads the next page of older entries and appends it.
  ///
  /// A device that has been reassigned and repaired for years has more than
  /// one page of chatter. The timeline used to read sixty entries and stop —
  /// not "sixty of two hundred", just an end, in the one place a technician
  /// looks to answer "who had this before". Anything older was invisible.
  ///
  /// A failed page deliberately leaves the entries already on screen alone.
  /// The user is reading a timeline; replacing it with an error page because
  /// the *tail* of it could not be fetched loses the part that arrived fine.
  Future<void> loadMore() async {
    final current = state.data;
    if (_isLoadingMore || current == null || !current.hasMore) return;

    _isLoadingMore = true;
    // Re-emitted so the footer spinner appears. The data is unchanged, so
    // there is no flicker — only the footer rebuilds.
    emit(state.success(current));

    final result = await _getHistory.page(
      _assetId,
      offset: current.entries.length,
    );
    if (isClosed) return;

    _isLoadingMore = false;
    result.fold(
      (_) => emit(state.success(current.copyWithNoMore())),
      (older) => emit(state.success(current.merge(older))),
    );
  }
}
