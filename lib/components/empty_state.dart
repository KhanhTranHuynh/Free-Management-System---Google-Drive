import 'package:flutter/material.dart';

/// Trạng thái "không có dữ liệu" dùng chung cho mọi danh sách trong app
/// (Tổng quan, Nhân viên, Nhật ký hệ thống...). Trước đây mỗi màn tự
/// viết 1 bản `Center(child: Text(...))` giống hệt nhau — gộp về đây.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
