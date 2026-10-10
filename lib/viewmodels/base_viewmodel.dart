import 'package:flutter/foundation.dart';

enum ViewState { idle, loading, success, error }

abstract class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  ViewState get state => _state;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  String? get errorMessage => _errorMessage;

  String? _loadingMessage;
  String? get loadingMessage => _loadingMessage;

  @protected
  void setLoading([String? message]) {
    _state = ViewState.loading;
    _loadingMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  @protected
  void setSuccess() {
    _state = ViewState.success;
    _loadingMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  @protected
  void setError(String message) {
    _state = ViewState.error;
    _loadingMessage = null;
    _errorMessage = message;
    notifyListeners();
  }

  @protected
  void setIdle() {
    _state = ViewState.idle;
    _loadingMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_state == ViewState.error) {
      _state = ViewState.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
