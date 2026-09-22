import 'package:flutter/material.dart';

import 'menu_item.dart';

/// Khai báo TOÀN BỘ menu có thể có trong app, CHƯA lọc theo vai trò.
/// Việc ẩn/hiện theo vai trò do [MenuService] xử lý riêng, dựa vào bảng
/// [menuVaiTro] — cố tình tách biệt "menu có gì" và "ai được xem gì",
/// giống hệt cặp `topMenu` / `menuRoles` bên bản React.
const List<MenuItem> topMenu = [
  MenuItem(
    key: 'trang_chu',
    title: 'Trang chủ',
    icon: Icons.home_outlined,
    link: '/trang-chu',
  ),
  MenuItem(
    key: 'nhan_vien',
    title: 'Nhân viên',
    icon: Icons.people_outline,
    link: '/nhan-vien',
  ),
  MenuItem(
    key: 'khach_hang',
    title: 'Khách hàng',
    icon: Icons.people_outline,
    link: '/khach-hang',
  ),
  MenuItem(
    key: 'album',
    title: 'Album',
    icon: Icons.photo_outlined,
    link: '/album',
  ),
  MenuItem(
    key: 'log',
    title: 'Log',
    icon: Icons.description_outlined,
    link: '/log',
  ),
  MenuItem(
    key: 'permission',
    title: 'Phân quyền',
    icon: Icons.verified_user_outlined,
    link: '/permission',
  ),
];
