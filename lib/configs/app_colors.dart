import 'package:flutter/material.dart';

/// Design token màu sắc dùng chung toàn app.
/// Không import bất kỳ thư mục nào khác của lib/ (đúng chiều phụ thuộc).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2F6FED);
  static const Color primaryDark = Color(0xFF1E4FBE);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE2E5EC);
  static const Color error = Color(0xFFE5484D);
  static const Color success = Color(0xFF2FA84F);

  static const Color backgroundDark = Color(0xFF15171E);
  static const Color surfaceDark = Color(0xFF1E212B);
  static const Color textPrimaryDark = Color(0xFFF2F3F7);
  static const Color textSecondaryDark = Color(0xFFA0A4B0);
  static const Color borderDark = Color(0xFF2C303B);
}
