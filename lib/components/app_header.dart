import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.tenNguoiDung,
    this.isDarkMode = false,
    this.onToggleDarkMode,
    this.onTapAvatar,
    this.dangOnline = true,
  });

  /// Họ tên người dùng — chỉ lấy 2 chữ cái đầu để hiển thị trong avatar
  /// (vd "Khánh Toàn" -> "KT").
  final String tenNguoiDung;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;
  final VoidCallback? onTapAvatar;
  final bool dangOnline;

  static const _mauLogoVien = Color(0xFFB98A4A); // nâu viền logo
  static const _mauLogoNen = Color(0xFFFDF3DC); // kem nhạt nền logo
  static const _mauFlow = Color(0xFFB4762A); // nâu vàng chữ "FLOW"
  static const _mauAvatar = Color(0xFF9B7A4A); // nâu avatar

  String get _chuCaiDau {
    final parts = tenNguoiDung.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1
        ? parts.last[0]
        : (parts.first.length > 1 ? parts.first[1] : '');
    return (first + last).toUpperCase();
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
          // ----- Logo -----
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _mauLogoNen,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _mauLogoVien.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(Icons.cloud, color: _mauLogoVien, size: 24),
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

          // ----- Avatar -----
          GestureDetector(
            onTap: onTapAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _mauAvatar,
                  child: Text(
                    _chuCaiDau,
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
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
