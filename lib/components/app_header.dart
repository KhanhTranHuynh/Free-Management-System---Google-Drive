import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../stores/auth_store.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.tenNguoiDung,
    this.isDarkMode = false,
    this.onToggleDarkMode,
    this.onTapAvatar,
    this.onTapTrangCaNhan,
    this.onLogout,
    this.dangOnline = true,
  });

  /// Họ tên người dùng — chỉ lấy 2 chữ cái đầu để hiển thị trong avatar
  /// (vd "Khánh Toàn" -> "KT").
  final String tenNguoiDung;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  /// Gọi thêm (nếu có) mỗi khi bấm vào avatar, trước khi menu hiện ra.
  final VoidCallback? onTapAvatar;

  /// Bấm "Trang cá nhân" trong menu -> điều hướng đến /trang-ca-nhan.
  final VoidCallback? onTapTrangCaNhan;

  /// Bấm "Logout" trong menu.
  /// Để trống (mặc định) -> AppHeader TỰ gọi AuthStore.dangXuat() (gọi API
  /// /xac-thuc/dang-xuat + tháo dữ liệu khỏi store) rồi điều hướng về màn
  /// đăng nhập. Truyền callback riêng nếu muốn tự xử lý theo cách khác.
  final VoidCallback? onLogout;

  final bool dangOnline;

  static const _mauLogoVien = Color(0xFFB98A4A); // nâu viền logo
  static const _mauLogoNen = Color(0xFFFDF3DC); // kem nhạt nền logo
  static const _mauFlow = Color(0xFFB4762A); // nâu vàng chữ "FLOW"
  static const _mauAvatar = Color(0xFF9B7A4A); // nâu avatar

  static const String _logoAssetPath = 'lib/assets/images/logo.svg';

  String get _chuCaiDau {
    final parts = tenNguoiDung
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      // Chỉ có 1 từ: lấy tối đa 2 chữ cái đầu của từ đó.
      final word = parts.first;
      return (word.length > 1 ? word.substring(0, 2) : word).toUpperCase();
    }

    // Lấy chữ cái đầu của 2 từ cuối cùng.
    // Vd: "Huỳnh Khánh Trân" -> "KT" (Khánh + Trân)
    final apCuoi = parts[parts.length - 2][0];
    final tenCuoi = parts[parts.length - 1][0];
    return (apCuoi + tenCuoi).toUpperCase();
  }

  /// Xử lý logout mặc định: gọi AuthStore.dangXuat() (call API + tháo
  /// dữ liệu store) rồi đưa người dùng về màn đăng nhập.
  Future<void> _dangXuatMacDinh(BuildContext context) async {
    final authStore = context.read<AuthStore>();
    await authStore.dangXuat();

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topSafePad = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topSafePad +
            14, // 14 = vertical padding gốc, giữ nguyên khoảng cách cũ bên dưới status bar
        left: 16,
        right: 16,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ----- Logo (SVG từ lib/assets/images/logo.svg) -----
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _mauLogoNen,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _mauLogoVien.withOpacity(0.5), width: 1.5),
            ),
            child: SvgPicture.asset(
              _logoAssetPath,
              colorFilter: const ColorFilter.mode(
                _mauLogoVien,
                BlendMode.srcIn,
              ),
              placeholderBuilder: (context) => const SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ----- Tên app + subtitle -----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'PHOTO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'FLOW',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _mauFlow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'QUẢN LÝ & CHỌN LỌC ẢNH STUDIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isDark ? Colors.white70 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // ----- Toggle dark mode -----
          IconButton(
            onPressed: onToggleDarkMode,
            icon: Icon(
              isDarkMode ? Icons.dark_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 4),

          // ----- Avatar + menu (Trang cá nhân / Logout) -----
          _AvatarMenu(
            chuCaiDau: _chuCaiDau,
            mauAvatar: _mauAvatar,
            dangOnline: dangOnline,
            isDark: isDark,
            onTapAvatar: onTapAvatar,
            onTapTrangCaNhan: onTapTrangCaNhan,
            onLogout: onLogout ?? () => _dangXuatMacDinh(context),
          ),
        ],
      ),
    );
  }
}

/// Avatar bấm vào sẽ mở menu: "Trang cá nhân" và "Logout".
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.chuCaiDau,
    required this.mauAvatar,
    required this.dangOnline,
    required this.isDark,
    this.onTapAvatar,
    this.onTapTrangCaNhan,
    this.onLogout,
  });

  final String chuCaiDau;
  final Color mauAvatar;
  final bool dangOnline;
  final bool isDark;
  final VoidCallback? onTapAvatar;
  final VoidCallback? onTapTrangCaNhan;
  final VoidCallback? onLogout;

  static const _mauChuMenu = Color(0xFF1E293B);

  void _xuLyChon(BuildContext context, String value) {
    switch (value) {
      case 'trang_ca_nhan':
        if (onTapTrangCaNhan != null) {
          onTapTrangCaNhan!();
        } else {
          Navigator.of(context).pushNamed('/trang-ca-nhan');
        }
        break;
      case 'logout':
        onLogout?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) => _xuLyChon(context, value),
      onOpened: onTapAvatar,
      offset: const Offset(0, 48),
      elevation: 6,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'trang_ca_nhan',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: isDark ? Colors.white70 : _mauChuMenu,
              ),
              const SizedBox(width: 12),
              Text(
                'Trang cá nhân',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : _mauChuMenu,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: isDark ? Colors.white70 : _mauChuMenu,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : _mauChuMenu,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: mauAvatar,
            child: Text(
              chuCaiDau,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (dangOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
