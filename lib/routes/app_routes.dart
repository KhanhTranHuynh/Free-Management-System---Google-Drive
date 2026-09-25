import 'package:flutter/material.dart';

import '../components/main_scaffold.dart'; // đổi path nếu bạn để khác chỗ
import '../pages/album_page.dart';
import '../pages/log_page.dart';
import '../pages/home_page.dart';
import '../pages/khach_hang_page.dart';
import '../pages/login_page.dart';
import '../pages/nhan_vien_page.dart';
import '../pages/not_found_page.dart';
import 'auth_guard.dart';

/// Khai báo tất cả route tập trung. Muốn thêm màn hình mới, sửa ở đây.
class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String home = '/home';
  static const String danhMucKhachHang = '/danh-muc-khach-hang';
  static const String nhanVien = '/nhan-vien';
  static const String khachHang = '/khach-hang';
  static const String album = '/album';
  static const String log = '/log';

  /// Các route cần đăng nhập mới được vào.
  static const Set<String> protected = {
    home,
    nhanVien,
    khachHang,
    album,
  };

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
      case nhanVien:
        page = const NhanVienPage();
        break;
      case khachHang:
        page = const KhachHangPage();
        break;
      case album:
        page = const AlbumPage();
        break;
      case log:
        page = const LogPage();
        break;
      default:
        page = const NotFoundPage();
    }

    if (protected.contains(name)) {
      page = AuthGuard(child: page);
    }

    // Hiện thanh điều hướng dưới cùng ở MỌI trang, trừ trang đăng nhập.
    // Áp tập trung ở đây nên KHÔNG page nào (kể cả page mới thêm sau này)
    // phải tự gọi Scaffold riêng cho phần này nữa.
    if (name != login) {
      page = ThanhDieuHuongWrapper(
        activeKey: activeKeyChoRoute(name),
        child: page,
      );
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
