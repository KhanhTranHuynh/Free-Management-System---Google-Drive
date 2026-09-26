import 'package:flutter/material.dart';

// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án.
import '../configs/app_colors.dart';

/// Chip lọc dùng chung (dùng ở Nhật ký hệ thống, Nhân viên...): dạng viên
/// thuốc, có số đếm, có thể kèm chấm màu để phân biệt loại. Khi được chọn
/// sẽ tô nền [AppColors.primary] và số đếm hiện trong bong bóng trắng mờ.
class ChipLoc extends StatelessWidget {
  const ChipLoc({
    super.key,
    required this.label,
    required this.dangChon,
    required this.onTap,
    this.soDem,
    this.mau,
    this.soDemDangNgoac = true,
  });

  final String label;
  final int? soDem; // null = không hiện số đếm
  final Color? mau; // null = không hiện chấm màu (vd chip "Tất cả")
  final bool dangChon;
  final VoidCallback onTap;
  // true: hiện "(5)" như bản Nhật ký hệ thống; false: hiện "5" trơn như
  // bản Nhân viên.
  final bool soDemDangNgoac;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: dangChon ? AppColors.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: dangChon ? null : Border.all(color: colorScheme.outline),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!dangChon && mau != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: mau),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: dangChon ? Colors.white : null,
              ),
            ),
            if (soDem != null) ...[
              const SizedBox(width: 6),
              if (dangChon)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$soDem',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                )
              else
                Text(
                  soDemDangNgoac ? '($soDem)' : '$soDem',
                  style: TextStyle(
                      fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
