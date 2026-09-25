import 'package:flutter/material.dart';

import '../views/tong_quan/tong_quan_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view (không chứa logic).
class TongQuanPage extends StatelessWidget {
  const TongQuanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tổng quan')),
      body: const SafeArea(child: TongQuanView()),
    );
  }
}
