import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../apis/models/user.dart';
import '../configs/menu_role.dart';
import '../stores/auth_store.dart';
import '../utils/lay_ma_vai_tro.dart';

/// Bọc quanh 1 page cần bảo vệ theo vai trò — tương đương
/// `<ProtectedRoute menuKey=... />` bên React.
///
/// Đây là lớp chặn ĐỘC LẬP với việc menu có hiện hay không: chặn user cố
/// tình điều hướng thẳng tới route dù menu tương ứng đã bị ẩn khỏi
/// [MenuService]. KHÔNG thay thế kiểm tra quyền ở BE — BE vẫn phải tự
/// kiểm tra độc lập.
///
/// Tự đọc `AuthStore.nguoiDung` qua Provider nên nơi gọi không cần truyền
/// user thủ công:
/// ```dart
/// '/permission': (context) => const QuyenRouteGuard(
///       menuKey: 'permission',
///       child: PermissionPage(),
///     ),
/// ```
class QuyenRouteGuard extends StatelessWidget {
  const QuyenRouteGuard({
    super.key,
    required this.menuKey,
    required this.child,
    this.duongDanKhongCoQuyen = '/404',
    this.trangKhongCoQuyen,
  });

  /// Key tra trong [menuVaiTro], phải trùng với MenuItem.key của route này.
  final String menuKey;

  final Widget child;

  /// Route điều hướng tới khi không đủ quyền (mặc định '/404').
  /// Bỏ qua nếu [trangKhongCoQuyen] được truyền.
  final String duongDanKhongCoQuyen;

  /// Widget hiển thị tại chỗ khi không đủ quyền, thay vì điều hướng đi.
  /// Nếu null -> tự điều hướng tới [duongDanKhongCoQuyen].
  final Widget? trangKhongCoQuyen;

  @override
  Widget build(BuildContext context) {
    // watch: nếu user đăng nhập/đăng xuất trong lúc đang đứng ở trang này
    // (vd token hết hạn -> AuthStore.dangXuat()) thì tự re-check ngay.
    final nguoiDung = context.watch<AuthStore>().nguoiDung;
    final vaiTro = layMaVaiTro(nguoiDung);
    final duocPhep = coQuyenTruyCapMenu(menuKey, vaiTro);

    if (duocPhep) return child;

    if (trangKhongCoQuyen != null) return trangKhongCoQuyen!;

    // Điều hướng sau khi build xong (không được gọi Navigator giữa lúc
    // build). replace để user không back lại được trang vừa bị chặn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(duongDanKhongCoQuyen);
      }
    });
    return const SizedBox.shrink();
  }
}

/// Bản dùng cho `go_router`: gắn vào `GoRoute(redirect: ...)` hoặc
/// `GoRouter(redirect: ...)` ở cấp router để chặn truy cập TRƯỚC khi
/// build page (đỡ phải render 1 frame trắng như QuyenRouteGuard).
///
/// ```dart
/// GoRoute(
///   path: '/permission',
///   redirect: (context, state) => quyenRedirect(
///     menuKey: 'permission',
///     nguoiDung: context.read<AuthStore>().nguoiDung,
///   ),
///   builder: (context, state) => const PermissionPage(),
/// ),
/// ```
String? quyenRedirect({
  required String menuKey,
  required NhanVien? nguoiDung,
  String duongDanKhongCoQuyen = '/404',
}) {
  final vaiTro = layMaVaiTro(nguoiDung);
  final duocPhep = coQuyenTruyCapMenu(menuKey, vaiTro);
  return duocPhep ? null : duongDanKhongCoQuyen;
}
