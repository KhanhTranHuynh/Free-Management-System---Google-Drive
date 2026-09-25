// lib/components/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_header.dart';
import '../configs/menu_role.dart';
import '../stores/auth_store.dart';
import '../stores/theme_store.dart';
import '../utils/lay_ma_vai_tro.dart';
import 'bottom_nav_bar.dart';

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
    link: '/log',
  ),
];

String activeKeyChoRoute(String? routeName) {
  switch (routeName) {
    case '/home':
      return 'trang_chu';
    case '/nhan-vien':
      return 'nhan_vien';
    case '/khach-hang':
      return 'khach_hang';
    case '/album':
      return 'album';
    case '/log':
      return 'log';
    default:
      return '';
  }
}

class ThanhDieuHuongWrapper extends StatelessWidget {
  const ThanhDieuHuongWrapper({
    super.key,
    required this.activeKey,
    required this.child,
    this.items = dsMucDieuHuongMacDinh,
    this.hienHeader = true,
  });

  /// Lấy từ `activeKeyChoRoute(routeName)`.
  final String activeKey;

  final Widget child;
  final List<ThanhDieuHuongItem> items;
  final bool hienHeader;

  @override
  Widget build(BuildContext context) {
    final nguoiDung = context.watch<AuthStore>().nguoiDung;
    final vaiTro = layMaVaiTro(nguoiDung);
    final dsItemDuocPhep =
        items.where((item) => coQuyenTruyCapMenu(item.key, vaiTro)).toList();

    final themeStore = context.watch<ThemeStore>();
    final isDarkMode = themeStore.mode == ThemeMode.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar trong suốt để nền AppHeader tự tràn lên tới mép trên
      // cùng; icon giờ/wifi/pin đổi sáng-tối theo theme cho tương phản.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: Column(
          children: [
            if (hienHeader)
              AppHeader(
                tenNguoiDung: nguoiDung?.hoTen ?? '?',
                isDarkMode: isDarkMode,
                onToggleDarkMode: () => themeStore.setMode(
                  isDarkMode ? ThemeMode.light : ThemeMode.dark,
                ),
              ),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: child,
              ),
            ),
          ],
        ),
        bottomNavigationBar: ThanhDieuHuongDuoi(
          items: dsItemDuocPhep,
          activeKey: activeKey,
          onChon: (item) {
            if (item.key == activeKey) return; // đang ở tab này rồi
            Navigator.of(context).pushReplacementNamed(item.link);
          },
        ),
      ),
    );
  }
}
