import 'dart:async';

/// Lightweight connectivity checker.
/// Uses a simple DNS lookup — replace with connectivity_plus when backend is ready.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // TODO: Replace with connectivity_plus when adding real backend.
    // For now always returns true so the UI never blocks on connectivity.
    return true;
  }
}
