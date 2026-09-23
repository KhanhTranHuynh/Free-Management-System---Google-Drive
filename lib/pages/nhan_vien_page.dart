import 'package:flutter/material.dart';

import '../views/nhan_vien/nhan_vien_list_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view (không chứa logic).
class NhanVienPage extends StatelessWidget {
  const NhanVienPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhân viên')),
      body: const SafeArea(child: NhanVienListView()),
    );
  }
}
