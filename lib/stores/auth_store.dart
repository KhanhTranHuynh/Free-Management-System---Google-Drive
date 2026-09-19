import 'package:flutter/foundation.dart';

import '../apis/api_exception.dart';
import '../apis/auth_api.dart';
import '../apis/models/user.dart';

class AuthStore extends ChangeNotifier {
  final AuthApi _api;
  AuthStore(this._api);

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Trả về true nếu đăng nhập thành công.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _api.login(email, password);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Có lỗi xảy ra, vui lòng thử lại';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    _error = null;
    notifyListeners();
  }
}
