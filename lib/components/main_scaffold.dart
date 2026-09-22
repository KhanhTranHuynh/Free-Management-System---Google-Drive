import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/menu_role.dart';
import '../stores/auth_store.dart';
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
    // CHƯA có route/page thật — bấm vào sẽ ra NotFoundPage cho tới khi
    // tạo page + đăng ký route trong app_routes.dart (xem TODO ở đó).
    link: '/log',
  ),
];

/// Suy ra key tab nào nên SÁNG ứng với 1 tên route hiện tại.
///
/// Dùng ở `AppRoutes.onGenerateRoute` để tự động bọc MỌI trang bằng
/// thanh điều hướng mà KHÔNG cần sửa từng page. Route là "trang con" của
/// 1 tab (vd "danh mục khách hàng" là con của tab "Khách hàng") thì map
/// về key của tab cha; route hoàn toàn không thuộc tab nào (login, 404,
/// log...) trả về '' — thanh vẫn hiện, chỉ không tab nào sáng.
String activeKeyChoRoute(String? routeName) {
  switch (routeName) {
    case '/home':
      return 'trang_chu';
    case '/nhan-vien':
      return 'nhan_vien';
    case '/khach-hang':
    case '/danh-muc-khach-hang': // trang con của tab "Khách hàng"
      return 'khach_hang';
    case '/album':
      return 'album';
    case '/log':
      return 'log';
    default:
      return '';
  }
}

/// Bọc quanh 1 trang để luôn có thanh điều hướng dưới cùng, đã LỌC theo
/// vai trò người dùng hiện tại (dùng chung `menuVaiTro` /
/// `coQuyenTruyCapMenu` với `QuyenRouteGuard`, nên 1 mục bị ẩn ở đây thì
/// route tương ứng cũng đang bị `QuyenRouteGuard` chặn — không lệch nhau).
///
/// LƯU Ý: widget này phải đọc `AuthStore` (qua Provider) để biết vai trò,
/// nên KHÔNG đặt trong lib/components/ theo quy ước "component không
/// import stores/apis" — nên để cùng chỗ với `AuthGuard`/`QuyenRouteGuard`
/// (vd lib/routes/ hoặc lib/views/), coi nó như 1 guard/layout của routing
/// chứ không phải UI thuần.
///
/// Trang bên trong (`child`) giữ NGUYÊN `Scaffold`/`AppBar` của chính nó
/// — widget này chỉ thêm 1 lớp `Scaffold` ngoài cùng có
/// `bottomNavigationBar`. Nested Scaffold trong Flutter chạy bình thường,
/// không cần đổi cấu trúc bên trong từng page.
///
/// KHÔNG gọi widget này trực tiếp trong từng page — áp tập trung 1 chỗ
/// duy nhất ở `AppRoutes.onGenerateRoute` (xem app_routes.dart), nhờ vậy
/// thêm trang mới sau này tự động có thanh này mà không cần sửa gì thêm.
class ThanhDieuHuongWrapper extends StatelessWidget {
  const ThanhDieuHuongWrapper({
    super.key,
    required this.activeKey,
    required this.child,
    this.items = dsMucDieuHuongMacDinh,
  });

  /// Lấy từ `activeKeyChoRoute(routeName)`.
  final String activeKey;

  final Widget child;
  final List<ThanhDieuHuongItem> items;

  @override
  Widget build(BuildContext context) {
    // watch: đăng nhập/đăng xuất hoặc đổi vai trò giữa lúc đang đứng ở
    // trang này thì thanh tự re-check ngay, giống cách QuyenRouteGuard
    // đang làm với route.
    final nguoiDung = context.watch<AuthStore>().nguoiDung;
    final vaiTro = layMaVaiTro(nguoiDung);
    final dsItemDuocPhep =
        items.where((item) => coQuyenTruyCapMenu(item.key, vaiTro)).toList();

    return Scaffold(
      body: child,
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
