import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/not_found_page.dart';
import 'auth_guard.dart';

/// Khai báo tất cả route tập trung. Muốn thêm màn hình mới, sửa ở đây.
class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String home = '/home';

  /// Các route cần đăng nhập mới được vào.
  static const Set<String> protected = {home};

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;

    Widget page;
    switch (name) {
      case login:
        page = const LoginPage();
        break;
      case home:
        page = const HomePage();
        break;
      default:
        page = const NotFoundPage();
    }

    if (protected.contains(name)) {
      page = AuthGuard(child: page);
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
