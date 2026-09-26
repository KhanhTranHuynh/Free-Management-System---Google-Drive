import 'package:flutter/material.dart';

// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án.
import '../configs/app_colors.dart';

// ============================================================
// Màu/nhãn/icon theo từng loại hành động — dùng chung cho chip lọc,
// icon từng dòng log và badge trạng thái bên phải mỗi dòng.
// TODO: chưa có token "info" (xanh dương) trong AppColors nên tạm khai
// báo cứng ở đây; nếu design token bổ sung AppColors.info thì thay hết
// mauThongTin bằng token đó.
// ============================================================
const Color mauThongTin = Color(0xFF3B82F6);

const Map<String, String> hanhDongTieuDe = {
  'tao': 'Tạo mới',
  'cap_nhat': 'Cập nhật',
  'xoa': 'Xoá',
  'chot_tat_ca_theo_album': 'Chốt tất cả theo album',
};

const Map<String, IconData> hanhDongIcon = {
  'tao': Icons.add_rounded,
  'cap_nhat': Icons.edit_rounded,
  'xoa': Icons.delete_outline_rounded,
  'chot_tat_ca_theo_album': Icons.check_rounded,
};

const Map<String, Color> hanhDongMau = {
  'tao': mauThongTin,
  'cap_nhat': AppColors.primary,
  'xoa': AppColors.error,
  'chot_tat_ca_theo_album': AppColors.success,
};

/// Nhãn trạng thái hiển thị ở badge bên phải mỗi dòng (vd "Thành công",
/// "Đã duyệt"...). Không phải field riêng từ BE — suy ra trực tiếp từ
/// hành động, giống cách card ở Tổng quan tô màu theo hành động.
/// TODO: nếu BE có field trạng thái thật riêng (vd 'trang_thai_hien_thi'),
/// ưu tiên đọc field đó trước, map này chỉ dùng làm fallback.
const Map<String, String> trangThaiTheoHanhDong = {
  'tao': 'Thành công',
  'cap_nhat': 'Đã sửa',
  'xoa': 'Đã xoá',
  'chot_tat_ca_theo_album': 'Đã duyệt',
};

// ============================================================
// Avatar theo tên (hash màu ổn định).
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

int avatarIndex(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash % avatarPalette.length;
}

String layChuCaiDau(String? hoTen) {
  if (hoTen == null || hoTen.trim().isEmpty) return '?';
  final words = hoTen.trim().split(RegExp(r'\s+'));
  final lastTwo = words.length <= 2 ? words : words.sublist(words.length - 2);
  return lastTwo.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
}
