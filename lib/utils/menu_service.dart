import '../configs/menu_item.dart';
import '../configs/menu_role.dart';
import '../configs/top_menu.dart';
import '../utils/lay_ma_vai_tro.dart';

/// Lọc [topMenu] theo vai trò của user hiện tại — tương đương hook
/// `useMenu()` bên React.
///
/// Gọi lại [layMenuTheoVaiTro] mỗi khi user/role thay đổi. Nếu app dùng
/// Provider/Riverpod/Bloc, nên bọc hàm này trong 1 getter/selector để tự
/// rebuild khi auth state đổi, ví dụ:
///
/// ```dart
/// final menuProvider = Provider<List<MenuItem>>((ref) {
///   final user = ref.watch(authProvider).user;
///   return MenuService.layMenuTheoVaiTro(user);
/// });
/// ```
class MenuService {
  const MenuService._();

  static List<MenuItem> layMenuTheoVaiTro(dynamic user) {
    final vaiTro = layMaVaiTro(user);

    return topMenu
        .where((menu) => coQuyenTruyCapMenu(menu.key, vaiTro))
        .map((menu) => _locMenuCon(menu, vaiTro))
        .toList();
  }

  /// Lọc luôn menu con: con không khai [MenuItem.key] riêng trong
  /// [menuVaiTro] thì mặc định cho hiện theo quyền của menu cha (không
  /// chặn thêm) — giữ đúng hành vi bản React.
  static MenuItem _locMenuCon(MenuItem menu, List<String> vaiTro) {
    if (!menu.coCon) return menu;

    final childrenDaLoc = menu.children.where((child) {
      final allowRoles = menuVaiTro[child.key];
      if (allowRoles == null) return true; // không khai key riêng -> giữ
      return allowRoles.any(vaiTro.contains);
    }).toList();

    return MenuItem(
      key: menu.key,
      title: menu.title,
      icon: menu.icon,
      link: menu.link,
      children: childrenDaLoc,
    );
  }
}
