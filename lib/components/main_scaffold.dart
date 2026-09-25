// lib/components/main_scaffold.dart
//
// Khung dùng chung cho mọi trang (trừ login): header cố định trên đầu +
// nội dung trang + thanh điều hướng dưới cùng. Áp tập trung 1 lần ở
// AppRoutes.onGenerateRoute (xem app_routes.dart) — không gọi trực tiếp
// trong từng page.
//
// Đặt ở lib/routes/ (không phải lib/components/) vì widget này đọc
// AuthStore + ThemeStore qua Provider — theo quy ước "component không
// import stores/apis; UI không tự gọi API" thì đây được coi là 1
// guard/layout của routing, không phải UI thuần.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_header.dart';
import '../configs/menu_role.dart';
import '../stores/auth_store.dart';
import '../stores/theme_store.dart';
import '../utils/lay_ma_vai_tro.dart';
import 'bottom_nav_bar.dart';

/// Khai báo 1 lần, dùng chung cho mọi trang.
///
/// Đây là danh sách CỐ ĐỊNH cho thanh dưới cùng (khác với menu Drawer đầy
/// đủ lấy theo quyền) — nếu cần ẩn/hiện theo quyền, lọc list này trước khi
/// truyền vào `ThanhDieuHuongWrapper.items`, hoặc thay `icon` bằng asset
/// SVG riêng nếu icon Material không khớp thiết kế.
const dsMucDieuHuongMacDinh = <ThanhDieuHuongItem>[
  ThanhDieuHuongItem(
    key: 'trang_chu',
    title: 'Trang chủ',
    icon: Icons.home_outlined,
    link: '/home', // phải khớp AppRoutes.home
  ),
  ThanhDieuHuongItem(
    key: 'nhan_vien',
    title: 'Nhân viên',
    icon: Icons.people_alt_outlined,
    link: '/nhan-vien', // phải khớp AppRoutes.nhanVien
  ),
  ThanhDieuHuongItem(
    key: 'khach_hang',
    title: 'Khách hàng',
    icon: Icons.assignment_ind_outlined,
    link: '/khach-hang', // phải khớp AppRoutes.khachHang
  ),
  ThanhDieuHuongItem(
    key: 'album',
    title: 'Album',
    icon: Icons.photo_library_outlined,
    link: '/album', // phải khớp AppRoutes.album
  ),
  ThanhDieuHuongItem(
    key: 'log', // phải khớp key trong menuVaiTro (menu_role.dart)
    title: 'Log',
    icon: Icons.history_outlined,
    link: '/log',
  ),
];

String activeKeyChoRoute(String? routeName) {
  switch (routeName) {
    case '/home':
      return 'trang_chu';
    case '/nhan-vien':
      return 'nhan_vien';
    case '/khach-hang':
      return 'khach_hang';
    case '/album':
      return 'album';
    case '/log':
      return 'log';
    default:
      return '';
  }
}

/// Bọc quanh 1 trang để luôn có header + thanh điều hướng dưới cùng, đã
/// LỌC theo vai trò người dùng hiện tại (dùng chung `menuVaiTro` /
/// `coQuyenTruyCapMenu` với `QuyenRouteGuard`, nên 1 mục bị ẩn ở đây thì
/// route tương ứng cũng đang bị `QuyenRouteGuard` chặn — không lệch nhau).
///
/// Trang bên trong (`child`) giữ NGUYÊN `Scaffold`/`AppBar` của chính nó
/// — widget này chỉ thêm 1 lớp `Scaffold` ngoài cùng có header +
/// `bottomNavigationBar`. Nested Scaffold trong Flutter chạy bình thường,
/// không cần đổi cấu trúc bên trong từng page.
///
/// KHÔNG gọi widget này trực tiếp trong từng page — áp tập trung 1 chỗ
/// duy nhất ở `AppRoutes.onGenerateRoute` (xem app_routes.dart), nhờ vậy
/// thêm trang mới sau này tự động có cả header lẫn thanh này mà không cần
/// sửa gì thêm.
class ThanhDieuHuongWrapper extends StatelessWidget {
  const ThanhDieuHuongWrapper({
    super.key,
    required this.activeKey,
    required this.child,
    this.items = dsMucDieuHuongMacDinh,

    // Cho phép tắt header ở 1 trang cụ thể nếu sau này cần (vd trang
    // full-screen) mà vẫn giữ thanh điều hướng dưới — mặc định luôn hiện.
    this.hienHeader = true,
  });

  /// Lấy từ `activeKeyChoRoute(routeName)`.
  final String activeKey;

  final Widget child;
  final List<ThanhDieuHuongItem> items;
  final bool hienHeader;

  @override
  Widget build(BuildContext context) {
    // watch: đăng nhập/đăng xuất, đổi vai trò, hoặc đổi theme giữa lúc
    // đang đứng ở trang này thì header/thanh dưới tự re-check ngay.
    final nguoiDung = context.watch<AuthStore>().nguoiDung;
    final vaiTro = layMaVaiTro(nguoiDung);
    final dsItemDuocPhep =
        items.where((item) => coQuyenTruyCapMenu(item.key, vaiTro)).toList();

    final themeStore = context.watch<ThemeStore>();

    return Scaffold(
      body: SafeArea(
        // bottom: false — để bottomNavigationBar tự lo phần safe-area
        // dưới (tránh double padding với SafeArea của ThanhDieuHuongDuoi).
        bottom: false,
        child: Column(
          children: [
            if (hienHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AppHeader(
                  // TODO: đổi tên field cho khớp model nguoiDung thật
                  // trong AuthStore (vd ten_hien_thi, ho_ten...).
                  tenNguoiDung: nguoiDung?.hoTen ?? '?',
                  isDarkMode: themeStore.mode == ThemeMode.dark,
                  // ThemeStore chỉ có setMode(ThemeMode), không có
                  // toggle() riêng — tự đảo giữa light/dark ở đây. Nếu
                  // đang ở ThemeMode.system, bấm 1 lần sẽ set thẳng về
                  // dark (không quay lại system qua nút này).
                  onToggleDarkMode: () => themeStore.setMode(
                    themeStore.mode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: ThanhDieuHuongDuoi(
        items: dsItemDuocPhep,
        activeKey: activeKey,
        onChon: (item) {
          if (item.key == activeKey) return; // đang ở tab này rồi
          Navigator.of(context).pushReplacementNamed(item.link);
        },
      ),
    );
  }
}
