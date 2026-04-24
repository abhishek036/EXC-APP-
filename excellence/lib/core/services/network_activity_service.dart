import 'package:flutter/foundation.dart';

class NetworkActivityService extends ChangeNotifier {
  int _activeRequests = 0;

  int get activeRequests => _activeRequests;

  bool get isBusy => _activeRequests > 0;

  void beginRequest() {
    _activeRequests += 1;
    if (_activeRequests == 1) {
      notifyListeners();
    }
  }

  void endRequest() {
    if (_activeRequests == 0) return;
    _activeRequests -= 1;
    if (_activeRequests == 0) {
      notifyListeners();
    }
  }
}