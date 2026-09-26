import 'package:flutter/material.dart';

/// Ô tìm kiếm dùng chung — có nút xoá nhanh khi đang có nội dung.
///
/// Có thể tái sử dụng ở các màn khác, chỉ cần truyền [controller],
/// [onChanged] và tuỳ chỉnh [hintText] cho phù hợp ngữ cảnh.
class OTimKiem extends StatelessWidget {
  const OTimKiem({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Tìm kiếm...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            isDense: true,
          ),
        );
      },
    );
  }
}
