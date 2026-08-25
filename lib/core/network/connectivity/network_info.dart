import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin abstraction over connectivity so repositories can fail fast with a
/// clear "no internet" message instead of waiting for a socket timeout
/// (spec §22).
abstract interface class NetworkInfo {
  Future<bool> get isConnected;

  Stream<bool> get onConnectivityChanged;
}

class ConnectivityNetworkInfo implements NetworkInfo {
  const ConnectivityNetworkInfo(this._connectivity);

  final Connectivity _connectivity;

  factory ConnectivityNetworkInfo.createDefault() =>
      ConnectivityNetworkInfo(Connectivity());

  @override
  Future<bool> get isConnected async =>
      _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  /// `connectivity_plus` reports the transport, not reachability. A `none`
  /// result is a definite no; anything else is a maybe that the RPC call will
  /// confirm.
  bool _hasConnection(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
}
