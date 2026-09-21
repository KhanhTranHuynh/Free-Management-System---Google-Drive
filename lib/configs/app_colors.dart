import 'package:flutter/material.dart';

/// Design token màu sắc dùng chung toàn app.
/// Đồng bộ với bộ màu chính (primary/gray/danger/success) trong tailwind.config.js
/// Không import bất kỳ thư mục nào khác của lib/ (đúng chiều phụ thuộc).
class AppColors {
  AppColors._();

  // ===== Primary (đồng bộ tailwind: primary.500 = #B37E37) =====
  static const Color primary = Color(0xFFB37E37);
  static const Color primaryDark = Color(0xFF96662B); // primary.600
  static const Color primaryLight = Color(0xFFEACEA5); // primary.200

  // ===== Nền & bề mặt (dựa trên gray.50 / gray.100) =====
  static const Color background = Color(0xFFF9FAFB); // gray.50
  static const Color surface = Color(0xFFFFFFFF);

  // ===== Chữ (dựa trên black.500 / gray.500) =====
  static const Color textPrimary = Color(0xFF111112); // black.500
  static const Color textSecondary = Color(0xFF68768A); // gray.500

  // ===== Viền (gray.300) =====
  static const Color border = Color(0xFFD2D6DC);

  // ===== Trạng thái (danger.500 / success.500) =====
  static const Color error = Color(0xFFF1595C);
  static const Color success = Color(0xFF50C793);

  // ===== Dark mode =====
  static const Color backgroundDark = Color(0xFF0F172A); // gray.900
  static const Color surfaceDark = Color(0xFF1E293B); // gray.800
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9FA6B2); // gray.400
  static const Color borderDark = Color(0xFF334155); // gray.700
}
