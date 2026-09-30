import 'package:flutter/material.dart';

import '../components/main_scaffold.dart'; // đổi path nếu bạn để khác chỗ
import '../pages/album_page.dart';
import '../pages/album_detail_page.dart';
import '../pages/nhat_ky_he_thong_page.dart';
import '../pages/tong_quan_page.dart.dart';
import '../pages/khach_hang_page.dart';
import '../pages/login_page.dart';
import '../pages/nhan_vien_page.dart';
import '../pages/not_found_page.dart';
import '../pages/trang_ca_nhan_page.dart';
import '../pages/lich_phan_cong_page.dart';
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
  static const String albumDetail = '/album/detail';
  static const String log = '/log';
  static const String TrangCaNhan = '/trang-ca-nhan';
  static const String LichPhanCong = '/lich-phan-cong';

  /// Các route cần đăng nhập mới được vào.
  static const Set<String> protected = {
    home,
    nhanVien,
    khachHang,
    album,
    albumDetail,
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    final uri = Uri.tryParse(name) ?? Uri();
    final segments = uri.pathSegments; // vd: ['album', 'detail', '123']

    String routeKey = name;
    String? idAlbum;
    if (segments.length >= 3 &&
        segments[0] == 'album' &&
        segments[1] == 'detail') {
      routeKey = albumDetail;
      idAlbum = segments[2];
    }

    Widget page;
    switch (routeKey) {
      case login:
        page = const LoginPage();
        break;
      case home:
        page = const TongQuanPage();
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
      case albumDetail:
        page = AlbumDetailPage(idAlbum: idAlbum ?? '');
        break;
      case log:
        page = const NhatKyHeThongPage();
        break;
      case TrangCaNhan:
        page = const TrangCaNhanPage();
        break;
      case LichPhanCong:
        page = const LichPhanCongPage();
        break;
      default:
        page = const NotFoundPage();
    }

    if (protected.contains(routeKey)) {
      page = AuthGuard(child: page);
    }

    // Hiện thanh điều hướng dưới cùng ở MỌI trang, trừ trang đăng nhập.
    if (routeKey != login) {
      page = ThanhDieuHuongWrapper(
        activeKey: activeKeyChoRoute(routeKey),
        child: page,
      );
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
