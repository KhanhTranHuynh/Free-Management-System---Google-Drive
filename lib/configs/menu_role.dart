/// Bảng phân quyền menu — NGUỒN CHÂN LÝ DUY NHẤT, dùng chung cho:
///  1. Ẩn/hiện menu trên UI (xem MenuService.layMenuTheoVaiTro).
///  2. Chặn truy cập route trái phép (xem QuyenRouteGuard / quyenRedirect).
///
/// key: trùng với MenuItem.key (hoặc key riêng của menu con nếu có).
/// value: danh sách mã vai trò được phép truy cập mục đó.
///
/// LƯU Ý: đây chỉ là lớp chặn/ẩn ở FE để tối ưu UX — KHÔNG thay thế kiểm
/// tra quyền thật ở BE. BE vẫn phải tự kiểm tra quyền độc lập.
const Map<String, List<String>> menuVaiTro = {
  'trang_chu': ['chu_studio', 'tho_chup', 'editor', 'khach_hang'],
  'nhan_vien': ['chu_studio', 'tho_chup', 'editor'],
  'khach_hang': ['chu_studio', 'tho_chup', 'editor'],
  'trang_ca_nhan': ['chu_studio', 'tho_chup', 'editor', 'khach_hang'],
  'album': ['chu_studio', 'tho_chup', 'editor', 'khach_hang'],
  'log': ['chu_studio'],
  'permission': ['chu_studio'],
};

/// Trả về true nếu ít nhất 1 vai trò trong [vaiTroCuaUser] nằm trong danh
/// sách được phép của [menuKey].
///
/// Menu/route KHÔNG được khai báo trong [menuVaiTro] -> mặc định KHÔNG
/// cho phép (an toàn hơn là mặc định cho phép mọi thứ chưa khai báo).
bool coQuyenTruyCapMenu(String menuKey, List<String> vaiTroCuaUser) {
  final allowRoles = menuVaiTro[menuKey] ?? const <String>[];
  if (allowRoles.isEmpty) return false;
  return allowRoles.any(vaiTroCuaUser.contains);
}
