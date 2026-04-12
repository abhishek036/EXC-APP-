import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight connectivity checker.
/// Uses connectivity_plus to determine whether any transport is available.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfoImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    final dynamic result = await _connectivity.checkConnectivity();

    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }

    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    return false;
  }
}
