import 'package:flutter/material.dart';

/// Trang hiển thị khi route không khớp bất kỳ case nào trong AppRoutes.
class TrangCaNhanView extends StatelessWidget {
  const TrangCaNhanView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Trang Cá Nhân')),
    );
  }
}
