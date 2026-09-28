import 'package:flutter/material.dart';

import '../../../../configs/app_colors.dart';

/// Tương ứng BottomActionBar.jsx: số ảnh đã chọn, Tất cả / Bỏ chọn,
/// ô nhập yêu cầu, nút thêm yêu cầu (và nút xoá nếu có onClearRequests).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.count,
    required this.requestController,
    this.onSelectAll,
    this.onDeselectAll,
    this.onAddRequest,
    this.onClearRequests,
    this.dangDoiChonTatCa = false,
    this.dangThemYeuCau = false,
    this.dangHuyYeuCau = false,
    this.coTheThemYeuCau = true,
  });

  final int count;
  final TextEditingController requestController;

  /// null = ẩn / vô hiệu hoá (không có quyền).
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onAddRequest;
  final VoidCallback? onClearRequests;

  final bool dangDoiChonTatCa;
  final bool dangThemYeuCau;
  final bool dangHuyYeuCau;
  final bool coTheThemYeuCau;

  @override
  Widget build(BuildContext context) {
    final disabledAdd =
        onAddRequest == null || dangThemYeuCau || !coTheThemYeuCau;
    final disabledClear =
        onClearRequests == null || dangHuyYeuCau || count == 0;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: AppColors.primary,
                    child:
                        const Icon(Icons.check, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text('$count ảnh',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: (onSelectAll == null || dangDoiChonTatCa)
                        ? null
                        : onSelectAll,
                    child: Text(dangDoiChonTatCa ? 'Đang xử lý...' : 'Tất cả'),
                  ),
                  TextButton(
                    onPressed: (onDeselectAll == null || dangDoiChonTatCa)
                        ? null
                        : onDeselectAll,
                    child: const Text('Bỏ chọn'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: requestController,
                      enabled: !dangThemYeuCau,
                      decoration: InputDecoration(
                        hintText: 'Yêu cầu chỉnh sửa cho $count ảnh...',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onClearRequests != null)
                    IconButton.outlined(
                      onPressed: disabledClear ? null : onClearRequests,
                      icon: dangHuyYeuCau
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.delete_outline),
                      tooltip: 'Hủy yêu cầu',
                    ),
                  IconButton.filled(
                    onPressed: disabledAdd ? null : onAddRequest,
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    icon: dangThemYeuCau
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add),
                    tooltip: 'Thêm yêu cầu',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
