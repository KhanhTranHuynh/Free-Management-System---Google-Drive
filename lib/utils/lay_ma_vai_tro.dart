/// Chuẩn hoá danh sách mã vai trò (role code) từ đối tượng user hiện tại.
/// Dùng chung cho cả [MenuService] lẫn [QuyenRouteGuard] — tương đương
/// hàm `getUserRoleCodes()` bên bản React, để không có 2 nơi đọc field
/// user.roles theo 2 cách khác nhau.
///
/// ⚠️ Hàm này viết theo kiểu "duck typing" (đọc field qua dynamic) để
/// không phụ thuộc cứng vào model User thật của app. Khi tích hợp, nên
/// thay bằng bản strongly-typed, ví dụ:
///
/// ```dart
/// List<String> layMaVaiTro(User? user) {
///   if (user == null) return const [];
///   return user.roles.map((r) => r.code).toList();
/// }
/// ```
List<String> layMaVaiTro(dynamic user) {
  if (user == null) return const [];

  try {
    final roles = user.roles;
    if (roles == null) return const [];
    if (roles is! Iterable) return const [];

    return roles
        .map((r) {
          if (r is String) return r;
          try {
            final code = r.code;
            return code?.toString();
          } catch (_) {
            return r?.toString();
          }
        })
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  } catch (_) {
    // user không có field `roles` (model khác cấu trúc) -> coi như chưa
    // xác định được vai trò, KHÔNG throw để tránh sập cả cây widget.
    return const [];
  }
}
