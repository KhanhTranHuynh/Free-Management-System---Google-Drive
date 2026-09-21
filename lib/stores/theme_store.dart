import 'package:flutter/material.dart';

/// Store nhỏ quản lý ThemeMode (sáng/tối/theo hệ thống) dùng chung toàn
/// app. Không gọi apis/ vì không có nghiệp vụ mạng nào liên quan.
class ThemeStore extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
