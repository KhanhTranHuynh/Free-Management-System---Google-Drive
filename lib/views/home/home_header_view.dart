import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../configs/app_colors.dart';
import '../../configs/app_spacing.dart';
import '../../stores/auth_store.dart';

/// Khối header trang chủ — đọc nguoiDung từ AuthStore để chào tên + vai
/// trò, minh hoạ dữ liệu đã được lưu trong store dùng lại được ngay.
class HomeHeaderView extends StatelessWidget {
  const HomeHeaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final nguoiDung = context.watch<AuthStore>().nguoiDung;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, ${nguoiDung?.hoTen ?? '---'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nguoiDung?.tenVaiTro.join(', ') ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
