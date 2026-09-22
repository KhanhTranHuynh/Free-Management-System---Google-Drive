import '../apis/models/user.dart';

/// Chuẩn hoá danh sách mã vai trò (role code) từ [NhanVien] hiện tại.
/// Dùng chung cho cả [MenuService] lẫn [QuyenRouteGuard] — tương đương
/// hàm `getUserRoleCodes()` bên bản React, chỉ khác là ở đây có type an
/// toàn thay vì đọc field qua dynamic.
///
/// `NhanVien.vaiTro` vốn đã là `List<String>` (mã vai trò, khác với
/// `tenVaiTro` là tên hiển thị) nên hàm này chỉ còn việc xử lý null-safety
/// khi chưa đăng nhập.
List<String> layMaVaiTro(NhanVien? nguoiDung) {
  if (nguoiDung == null) return const [];
  return nguoiDung.vaiTro;
}
