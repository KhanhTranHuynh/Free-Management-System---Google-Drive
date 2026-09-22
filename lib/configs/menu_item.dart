import 'package:flutter/widgets.dart';

/// Đại diện 1 mục trong menu ngang/dọc của app.
/// Tương đương 1 phần tử trong `topMenu` (React) — thêm kiểu tường minh
/// để tránh gõ nhầm field khi cấu hình menu.
class MenuItem {
  const MenuItem({
    required this.key,
    required this.title,
    this.icon,
    this.link,
    this.children = const [],
  });

  /// Định danh duy nhất, dùng để tra quyền trong [menuVaiTro].
  /// PHẢI khớp key trong bảng phân quyền ở menu_role.dart.
  final String key;

  final String title;

  /// Icon hiển thị (thay cho string "heroicons-outline:home" bên React).
  final IconData? icon;

  /// Route link. Null nếu đây chỉ là menu group cha chứa [children].
  final String? link;

  /// Menu con (dropdown). Rỗng nếu là menu đơn không có con.
  final List<MenuItem> children;

  bool get coCon => children.isNotEmpty;
}
