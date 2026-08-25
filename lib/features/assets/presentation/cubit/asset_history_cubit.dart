import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/cubit/view_state.dart';
import '../../domain/entities/asset_history.dart';
import '../../domain/usecases/asset_usecases.dart';

/// ViewModel for one asset's service life.
class AssetHistoryCubit extends Cubit<SimpleViewState<AssetHistory>> {
  AssetHistoryCubit(this._getHistory)
    : super(const SimpleViewState<AssetHistory>());

  final GetAssetHistory _getHistory;

  Future<void> load(int assetId, {bool refresh = false}) async {
    emit(refresh ? state.refreshing() : state.loading());

    final result = await _getHistory(assetId);
    if (isClosed) return;

    emit(result.fold(state.failed, state.success));
  }
}
