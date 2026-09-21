import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/loading_view.dart';
import '../../configs/app_colors.dart';
import '../../configs/app_spacing.dart';
import '../../stores/auth_store.dart';

/// Khối hiển thị TOÀN BỘ dữ liệu đang được lưu trong AuthStore (thông tin
/// người dùng đầy đủ + bản đồ quyền) — đúng yêu cầu "in dữ liệu đang được
/// lưu trong stores ra" ngay tại trang chủ.
class UserInfoView extends StatelessWidget {
  const UserInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    final authStore = context.watch<AuthStore>();
    final nguoiDung = authStore.nguoiDung;
    final quyen = authStore.quyen;

    if (nguoiDung == null) {
      return const LoadingView(message: 'Chưa có dữ liệu người dùng...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KhungThongTin(
          tieuDe: 'Thông tin tài khoản (AuthStore.nguoiDung)',
          children: [
            _dong('Họ tên', nguoiDung.hoTen),
            _dong('Email', nguoiDung.email),
            _dong('Số điện thoại', nguoiDung.soDienThoai),
            _dong('Vai trò', nguoiDung.vaiTro.join(', ')),
            _dong('Tên vai trò', nguoiDung.tenVaiTro.join(', ')),
            _dong('Loại đăng nhập', nguoiDung.loaiDangNhap),
            _dong('Trạng thái', nguoiDung.trangThai ? 'Hoạt động' : 'Khoá'),
            _dong('ID studio', nguoiDung.idStudioLocal),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _KhungThongTin(
          tieuDe: 'Quyền (AuthStore.quyen)',
          children: (quyen == null || quyen.isEmpty)
              ? [const Text('Không có quyền nào được cấp.')]
              : quyen.entries
                  .map((e) => _dong(e.key, e.value))
                  .toList(growable: false),
        ),
      ],
    );
  }

  Widget _dong(String nhan, String giaTri) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              nhan,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(giaTri.isEmpty ? '---' : giaTri)),
        ],
      ),
    );
  }
}

class _KhungThongTin extends StatelessWidget {
  const _KhungThongTin({required this.tieuDe, required this.children});

  final String tieuDe;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tieuDe,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Divider(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}
