import 'package:flutter/material.dart';

/// Chỉ báo trạng thái dạng "chấm màu + nhãn", dùng chung cho:
///   - Badge trạng thái album ở Tổng quan (trước là `_TrangThaiBadge`)
///   - Chấm "Hoạt động"/"Khóa" ở Nhân viên (trước là `_TrangThaiDot`)
/// Hai widget cũ khác tên nhưng cùng 1 ý tưởng (chấm tròn màu + text
/// cùng màu), chỉ khác ở chỗ có bọc nền pill hay không — gộp lại bằng
/// tham số [filled].
///
/// [filled] = true: dạng pill có nền màu nhạt phía sau — dùng khi đây
///   là thông tin CHÍNH của dòng, cần nổi bật (vd trạng thái album).
/// [filled] = false: chấm + chữ trần, không nền — dùng khi đây là
///   thông tin PHỤ đi kèm badge khác trên cùng 1 dòng (vd trạng thái
///   hoạt động/khóa nằm cạnh badge vai trò của nhân viên).
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (!filled) return row;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: row,
    );
  }
}
