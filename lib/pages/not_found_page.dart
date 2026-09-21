import 'package:flutter/material.dart';

/// Trang hiển thị khi route không khớp bất kỳ case nào trong AppRoutes.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('404 - Không tìm thấy trang')),
    );
  }
}
