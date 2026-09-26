import 'package:flutter/material.dart';

// ============================================================
// Avatar theo tên (hash màu ổn định) — dùng chung cho mọi màn cần hiện
// avatar chữ cái đầu (Tổng quan, Nhật ký hệ thống, Nhân viên...).
// Gom về đây theo đúng TODO cũ vì logic này đã lặp lại ở màn thứ 3.
// ============================================================
const List<Color> avatarPalette = [
  Color(0xFFE0E7FF),
  Color(0xFFCCFBF1),
  Color(0xFFFFEDD5),
  Color(0xFFF3E8FF),
  Color(0xFFCFFAFE),
];

const List<Color> avatarPaletteFg = [
  Color(0xFF4338CA),
  Color(0xFF0F766E),
  Color(0xFFC2410C),
  Color(0xFF7E22CE),
  Color(0xFF0E7490),
];

/// Chọn 1 màu ổn định trong [avatarPalette]/[avatarPaletteFg] theo [seed]
/// (thường là tên người hoặc mã định danh) — cùng seed luôn ra cùng màu.
int avatarIndex(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash % avatarPalette.length;
}

/// Lấy tối đa 2 chữ cái đầu (từ 2 từ cuối của họ tên) để hiện trong avatar.
String layChuCaiDau(String? hoTen) {
  if (hoTen == null || hoTen.trim().isEmpty) return '?';
  final words = hoTen.trim().split(RegExp(r'\s+'));
  final lastTwo = words.length <= 2 ? words : words.sublist(words.length - 2);
  return lastTwo.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
}
