import 'package:flutter/material.dart';

import '../configs/app_colors.dart';

const Map<String, Color> hanhDongMau = {
  'tao': AppColors.info,
  'cap_nhat': AppColors.primary,
  'xoa': AppColors.error,
  'chot_tat_ca_theo_album': AppColors.success,
};

/// Icon cho timeline rút gọn ở Tổng quan (khối "Nhật ký hệ thống").
const Map<String, IconData> hanhDongIconTimeline = {
  'tao': Icons.arrow_upward_rounded,
  'cap_nhat': Icons.edit_rounded,
  'xoa': Icons.close_rounded,
  'chot_tat_ca_theo_album': Icons.check_rounded,
};

/// Icon cho từng dòng ở màn Nhật ký hệ thống (danh sách đầy đủ).
const Map<String, IconData> hanhDongIconDanhSach = {
  'tao': Icons.add_rounded,
  'cap_nhat': Icons.edit_rounded,
  'xoa': Icons.delete_outline_rounded,
  'chot_tat_ca_theo_album': Icons.check_rounded,
};

/// Nhãn dạng câu quá khứ — dùng để tự build mô tả log ở Tổng quan khi
/// `ghi_chu` null (vd "Hệ thống đã tạo mới album").
const Map<String, String> hanhDongLabel = {
  'tao': 'đã tạo mới',
  'cap_nhat': 'đã cập nhật',
  'xoa': 'đã xoá',
  'chot_tat_ca_theo_album': 'đã chốt tất cả yêu cầu chỉnh sửa của',
};

/// Nhãn dạng tiêu đề — dùng cho chip lọc & tiêu đề mỗi dòng log ở màn
/// Nhật ký hệ thống (vd "Tạo mới", "Cập nhật"...).
const Map<String, String> hanhDongTieuDe = {
  'tao': 'Tạo mới',
  'cap_nhat': 'Cập nhật',
  'xoa': 'Xoá',
  'chot_tat_ca_theo_album': 'Chốt tất cả theo album',
};

/// Nhãn trạng thái hiện ở badge cuối mỗi dòng log — suy ra trực tiếp từ
/// hành động (không phải field riêng từ BE).
/// TODO: nếu BE có field trạng thái thật riêng (vd 'trang_thai_hien_thi'),
/// ưu tiên đọc field đó trước, map này chỉ dùng làm fallback.
const Map<String, String> trangThaiTheoHanhDong = {
  'tao': 'Thành công',
  'cap_nhat': 'Đã sửa',
  'xoa': 'Đã xoá',
  'chot_tat_ca_theo_album': 'Đã duyệt',
};

/// Nhãn tên bảng (dùng khi build mô tả log tự động ở Tổng quan, và cho
/// tag "ten_bang_hien_thi" fallback ở Nhật ký hệ thống).
const Map<String, String> tenBangLabel = {
  'album': 'album',
  'yeu_cau_chinh_sua': 'yêu cầu chỉnh sửa',
  'tep_anh': 'tệp ảnh',
};
