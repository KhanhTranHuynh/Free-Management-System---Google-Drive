import 'package:flutter/material.dart';

// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án (đang giả định cùng cấp với apis/ ở lib/configs/).
import '../configs/app_colors.dart';
import 'avatar_util.dart';
import 'hanh_dong_util.dart';

// ============================================================
// File hằng số / hàm thuần (pure helper) riêng cho màn Tổng quan.
//
// FIX (chống phân mảnh): các thứ trước đây bị định nghĩa TRÙNG LẶP ở cả
// tong_quan_util.dart và nhat_ky_he_thong_util.dart (avatarPalette,
// avatarPaletteFg, avatarIndex, layChuCaiDau, mauThongTin, map màu/nhãn
// hành động...) đã được gộp về 2 file dùng chung:
//   - avatar_util.dart   -> avatar theo tên
//   - hanh_dong_util.dart -> màu/icon/nhãn theo hành động
//
// File này `export` lại 2 file trên để tong_quan_view.dart KHÔNG cần
// sửa câu import (`import '../../utils/tong_quan_util.dart'` vẫn thấy
// được avatarIndex, layChuCaiDau, hanhDongMau, hanhDongIconTimeline...
// như cũ). tong_quan_util.dart giờ chỉ còn giữ đúng những gì thật sự
// riêng của màn Tổng quan: trangThaiMap (trạng thái ALBUM, không phải
// hành động) và moTaLog().
// ============================================================
export 'avatar_util.dart';
export 'hanh_dong_util.dart';

/// Trạng thái của 1 ALBUM (khác với "hành động" trong nhật ký hệ thống)
/// — chỉ dùng riêng ở khối "Tiến độ xử lý album" và badge trên từng
/// album tile ở màn Tổng quan.
class TrangThaiInfo {
  const TrangThaiInfo(this.label, this.color);
  final String label;
  final Color color;
}

const Map<String, TrangThaiInfo> trangThaiMap = {
  'chua_xu_ly': TrangThaiInfo('Chưa xử lý', AppColors.primary),
  'dang_xu_ly': TrangThaiInfo('Đang xử lý', AppColors.info),
  'hoan_thanh': TrangThaiInfo('Hoàn thành', AppColors.success),
  'huy': TrangThaiInfo('Đã huỷ', AppColors.error),
};

/// nhat_ky_he_thong.ghi_chu hiện đang null -> tự build mô tả từ
/// ten_bang + hanh_dong (dùng hanhDongLabel/tenBangLabel từ
/// hanh_dong_util.dart).
String moTaLog(Map<String, dynamic> log) {
  final hanhDongRaw = log['hanh_dong']?.toString() ?? '';
  final tenBangRaw = log['ten_bang']?.toString() ?? '';
  final hanhDong = hanhDongLabel[hanhDongRaw] ?? hanhDongRaw;
  final banLabel = tenBangLabel[tenBangRaw] ?? tenBangRaw;
  return 'Hệ thống $hanhDong $banLabel';
}
