import 'package:flutter/material.dart';

// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án.
import '../configs/app_colors.dart';

/// Banner lỗi nền nhạt, không chặn hết màn hình — dùng khi màn VẪN CÒN
/// dữ liệu cũ hiển thị phía dưới (vd Tổng quan: tải lại lỗi nhưng vẫn
/// giữ dữ liệu cache của lần tải trước).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}

/// Trạng thái lỗi CHIẾM TOÀN BỘ khu vực nội dung, kèm nút "Thử lại" —
/// dùng khi KHÔNG còn dữ liệu cũ nào để hiện (vd Nhân viên, Nhật ký hệ
/// thống khi load lần đầu bị lỗi).
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
