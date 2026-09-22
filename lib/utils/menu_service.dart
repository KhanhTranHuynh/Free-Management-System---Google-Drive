import '../apis/models/user.dart';
import '../configs/menu_item.dart';
import '../configs/menu_role.dart';
import '../configs/top_menu.dart';
import '../utils/lay_ma_vai_tro.dart';

/// Lọc [topMenu] theo vai trò của [NhanVien] hiện tại — tương đương hook
/// `useMenu()` bên React.
///
/// Gọi lại [layMenuTheoVaiTro] mỗi khi `AuthStore.nguoiDung` thay đổi.
/// Cách dùng thực tế với AuthStore (đã là ChangeNotifier):
///
/// ```dart
/// final nguoiDung = context.watch<AuthStore>().nguoiDung;
/// final menus = MenuService.layMenuTheoVaiTro(nguoiDung);
/// ```
class MenuService {
  const MenuService._();

  static List<MenuItem> layMenuTheoVaiTro(NhanVien? nguoiDung) {
    final vaiTro = layMaVaiTro(nguoiDung);

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
