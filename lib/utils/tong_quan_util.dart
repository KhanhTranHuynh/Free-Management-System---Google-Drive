import 'package:flutter/material.dart';

// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án (đang giả định cùng cấp với apis/ ở lib/configs/).
import '../../configs/app_colors.dart';

// ============================================================
// File tổng hợp các hằng số / hàm thuần (pure helper) dùng cho màn
// Tổng quan — không chứa widget, để tong_quan_view.dart gọn hơn và
// có thể unit-test riêng phần logic này sau này.
// ============================================================

/// Màu dùng riêng cho màn Tổng quan nhưng KHÔNG có token tương ứng
/// trong AppColors (hiện chỉ có primary/gray/danger/success).
/// TODO: nếu design token thêm màu "info" (xanh dương), thay hết các
/// chỗ dùng biến này bằng AppColors.info.
const Color mauThongTin = Color(0xFF3B82F6);

// ============================================================
// MAP TRẠNG THÁI / NHÃN — khớp TRANG_THAI_MAP, TEN_BANG_LABEL,
// HANH_DONG_LABEL bên React. Màu ưu tiên tái dùng AppColors để đồng bộ
// và dễ sửa toàn cục sau này.
// ============================================================
class TrangThaiInfo {
  const TrangThaiInfo(this.label, this.color);
  final String label;
  final Color color;
}

const Map<String, TrangThaiInfo> trangThaiMap = {
  'chua_xu_ly': TrangThaiInfo('Chưa xử lý', AppColors.primary),
  'dang_xu_ly': TrangThaiInfo('Đang xử lý', mauThongTin),
  'hoan_thanh': TrangThaiInfo('Hoàn thành', AppColors.success),
  'huy': TrangThaiInfo('Đã huỷ', AppColors.error),
};

const Map<String, String> tenBangLabel = {
  'album': 'album',
  'yeu_cau_chinh_sua': 'yêu cầu chỉnh sửa',
  'tep_anh': 'tệp ảnh',
};

const Map<String, String> hanhDongLabel = {
  'tao': 'đã tạo mới',
  'cap_nhat': 'đã cập nhật',
  'xoa': 'đã xoá',
  'chot_tat_ca_theo_album': 'đã chốt tất cả yêu cầu chỉnh sửa của',
};

/// Icon + màu nền đặc cho mốc thời gian trong "Nhật ký hệ thống" (icon
/// trắng trên nền tròn màu đặc). Màu tái dùng từ trangThaiMap ở trên để
/// cùng một hành động luôn ra cùng một màu trong toàn màn.
const Map<String, IconData> hanhDongIcon = {
  'tao': Icons.arrow_upward_rounded,
  'cap_nhat': Icons.edit_rounded,
  'xoa': Icons.close_rounded,
  'chot_tat_ca_theo_album': Icons.check_rounded,
};

const Map<String, Color> hanhDongMauNen = {
  'tao': mauThongTin,
  'cap_nhat': AppColors.primary,
  'xoa': AppColors.error,
  'chot_tat_ca_theo_album': AppColors.success,
};

/// nhat_ky_he_thong.ghi_chu hiện đang null -> tự build mô tả từ
/// ten_bang + hanh_dong, giống moTaLog() bên React.
String moTaLog(Map<String, dynamic> log) {
  final hanhDongRaw = log['hanh_dong']?.toString() ?? '';
  final tenBangRaw = log['ten_bang']?.toString() ?? '';
  final hanhDong = hanhDongLabel[hanhDongRaw] ?? hanhDongRaw;
  final banLabel = tenBangLabel[tenBangRaw] ?? tenBangRaw;
  return 'Hệ thống $hanhDong $banLabel';
}

// ============================================================
// AVATAR — màu ổn định theo id (hash), khớp avatarClass() bên React.
// Đây là bảng màu trang trí thuần tuý (indigo/teal/cam/tím/cyan), độc
// lập với AppColors vì hệ thống design token hiện chưa có bộ màu
// avatar riêng — giữ nguyên để tránh mọi avatar cùng ra 1 màu primary.
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

int avatarIndex(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash % avatarPalette.length;
}

/// Lấy chữ cái đầu của 2 từ cuối trong họ tên (vd "Nguyễn Văn An" -> "VA"),
/// khớp layChuCaiDau() bên React.
String layChuCaiDau(String? hoTen) {
  if (hoTen == null || hoTen.trim().isEmpty) return '?';
  final words = hoTen.trim().split(RegExp(r'\s+'));
  final lastTwo = words.length <= 2 ? words : words.sublist(words.length - 2);
  return lastTwo.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
}
