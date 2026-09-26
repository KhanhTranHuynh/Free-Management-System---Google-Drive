import 'package:flutter/material.dart';

// ============================================================
// Avatar theo tên (hash màu ổn định) — dùng chung cho MỌI màn cần hiện
// avatar chữ cái đầu (Tổng quan, Nhật ký hệ thống, Nhân viên...).
//
// Đây là NGUỒN DUY NHẤT cho avatarPalette/avatarPaletteFg/avatarIndex/
// layChuCaiDau. Trước đây 3 file (tong_quan_util.dart,
// nhat_ky_he_thong_util.dart và file này) đều tự định nghĩa lại y hệt
// 4 thứ này — sửa màu avatar phải sửa 3 chỗ, rất dễ lệch nhau. Từ giờ
// mọi view/util khác chỉ import file này, KHÔNG tự khai báo lại.
// ============================================================
const List<Color> avatarPalette = [
  Color(0xFFE0E7FF), // indigo-100
  Color(0xFFCCFBF1), // teal-100
  Color(0xFFFFEDD5), // orange-100
  Color(0xFFF3E8FF), // purple-100
  Color(0xFFCFFAFE), // cyan-100
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

/// Lấy chữ cái đầu của 2 từ cuối trong họ tên (vd "Nguyễn Văn An" -> "VA").
String layChuCaiDau(String? hoTen) {
  if (hoTen == null || hoTen.trim().isEmpty) return '?';
  final words = hoTen.trim().split(RegExp(r'\s+'));
  final lastTwo = words.length <= 2 ? words : words.sublist(words.length - 2);
  return lastTwo.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
}

// ============================================================
// Màu tuỳ chỉnh theo dữ liệu BE (vd field `mau_sac` dạng "#cc0022").
// Dùng khi BE đã gán sẵn màu cho từng bản ghi (nhân viên, vai trò...)
// thay vì suy màu từ hash tên như ở trên. Tách riêng khỏi avatarPalette
// vì đây không phải bảng màu cố định mà là parse trực tiếp từ dữ liệu.
// ============================================================

/// Parse chuỗi hex dạng "#cc0022" / "cc0022" (có thể kèm alpha 8 ký tự)
/// thành [Color]. Trả về [fallback] nếu [hex] rỗng, null hoặc sai định dạng
/// — luôn gọi được an toàn kể cả khi BE trả về giá trị bẩn.
Color parseHexColor(String? hex, {required Color fallback}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s'; // thêm alpha nếu BE chỉ gửi RGB
  if (s.length != 8) return fallback;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return fallback;
  return Color(value);
}

/// Chọn màu chữ (đen/trắng) tương phản tốt với [bg] theo độ sáng tương đối,
/// để chữ luôn đọc được dù [bg] là màu tuỳ ý do BE gán (sáng hoặc tối).
Color contrastFg(Color bg) {
  return bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
}
