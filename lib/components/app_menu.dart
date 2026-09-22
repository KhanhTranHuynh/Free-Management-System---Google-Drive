import 'package:flutter/material.dart';

import '../configs/menu_item.dart';

/// Chuẩn hoá path: bỏ query/hash, bỏ dấu "/" thừa ở cuối.
/// Tương đương `normalizePath()` bên React.
String _chuanHoaDuongDan(String? raw) {
  if (raw == null) return '/';
  final value = raw.trim();
  if (value.isEmpty) return '/';

  final pathOnly = value.split('?').first.split('#').first;
  if (pathOnly.length > 1 && pathOnly.endsWith('/')) {
    return pathOnly.substring(0, pathOnly.length - 1);
  }
  return pathOnly;
}

/// So khớp theo SEGMENT, không phải `startsWith` thô — tránh match nhầm
/// vd "/don-hang-abc" với prefix "/don-hang".
/// Tương đương `pathStartsWithSegment()` bên React.
bool duongDanKhopMenu(String? pathnameRaw, String? prefixRaw) {
  final pathname = _chuanHoaDuongDan(pathnameRaw);
  final prefix = _chuanHoaDuongDan(prefixRaw);

  if (prefix == '/') return pathname == '/';
  return pathname == prefix || pathname.startsWith('$prefix/');
}

/// Xác định 1 menu item có đang "active" so với path hiện tại không.
/// Tương đương `isTopMenuActive()` bên React.
///
/// Mặc định: active nếu path hiện tại nằm trong "nhánh" của item.link —
/// để các trang con (vd chi tiết đơn hàng) vẫn giữ menu cha được active.
/// Thêm case riêng theo `item.key` khi 1 menu cần gộp nhiều path không
/// cùng prefix (xem ví dụ `don_hang` / `cong_no` bên dưới).
bool menuDangActive(MenuItem item, String pathname) {
  switch (item.key) {
    case 'don_hang':
      return duongDanKhopMenu(pathname, '/don-hang');
    case 'cong_no':
      return duongDanKhopMenu(pathname, '/cong-no');
    case 'don_hang_khach_hang':
      return duongDanKhopMenu(pathname, '/don-hang/danh-sach') ||
          duongDanKhopMenu(pathname, '/don-hang/tao-don-hang') ||
          duongDanKhopMenu(pathname, '/don-hang/sua-don-hang') ||
          duongDanKhopMenu(pathname, '/don-hang/chi-tiet-don-hang');
    case 'cong_no_khach_hang':
      return duongDanKhopMenu(pathname, '/khach-hang/cong-no');
    default:
      return item.link != null && duongDanKhopMenu(pathname, item.link);
  }
}

/// Danh sách menu dạng Drawer/NavigationRail, tự tô sáng item active.
/// Nhận vào danh sách menu ĐÃ LỌC theo quyền (từ `MenuService`), widget
/// này KHÔNG tự kiểm tra quyền — tách biệt UI khỏi logic phân quyền.
///
/// Cách dùng thực tế với AuthStore:
/// ```dart
/// final nguoiDung = context.watch<AuthStore>().nguoiDung;
/// final menus = MenuService.layMenuTheoVaiTro(nguoiDung);
///
/// AppMenuList(
///   menus: menus,
///   pathname: ModalRoute.of(context)?.settings.name ?? '/',
///   onChon: (item) => Navigator.pushNamed(context, item.link!),
/// );
/// ```
class AppMenuList extends StatelessWidget {
  const AppMenuList({
    super.key,
    required this.menus,
    required this.pathname,
    required this.onChon,
  });

  final List<MenuItem> menus;
  final String pathname;
  final ValueChanged<MenuItem> onChon;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final item = menus[index];

        if (item.coCon) {
          final coItemConActive =
              item.children.any((c) => menuDangActive(c, pathname));

          return ExpansionTile(
            leading: item.icon != null ? Icon(item.icon) : null,
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight:
                    coItemConActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            initiallyExpanded: coItemConActive,
            children: item.children.map((child) {
              final active = menuDangActive(child, pathname);
              return _MenuTile(item: child, active: active, onTap: onChon);
            }).toList(),
          );
        }

        final active = menuDangActive(item, pathname);
        return _MenuTile(item: item, active: active, onTap: onChon);
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final MenuItem item;
  final bool active;
  final ValueChanged<MenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: item.icon != null
            ? Icon(
                item.icon,
                color: active ? theme.colorScheme.onPrimary : null,
              )
            : null,
        title: Text(
          item.title,
          style: TextStyle(
            color: active ? theme.colorScheme.onPrimary : null,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => onTap(item),
      ),
    );
  }
}
