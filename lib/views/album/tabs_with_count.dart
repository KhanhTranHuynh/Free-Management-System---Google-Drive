import 'package:flutter/material.dart';

class TabCountOption {
  const TabCountOption({
    required this.gia_tri,
    required this.nhan,
    required this.soLuong,
  });

  /// null = "Tất cả"
  final String? gia_tri;
  final String nhan;
  final int soLuong;
}

/// Dãy tab cuộn ngang, mỗi tab có badge đếm số lượng — convert từ
/// TabsWithCount.jsx bên React (dùng ChoiceChip thay cho div tab tự vẽ).
class TabsWithCount extends StatelessWidget {
  const TabsWithCount({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<TabCountOption> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = options[index];
          final daChon = opt.gia_tri == value;
          return ChoiceChip(
            label: Text('${opt.nhan} (${opt.soLuong})'),
            selected: daChon,
            onSelected: (_) => onChanged(opt.gia_tri),
          );
        },
      ),
    );
  }
}
