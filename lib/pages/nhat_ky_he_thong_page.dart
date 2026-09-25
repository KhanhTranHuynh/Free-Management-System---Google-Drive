import 'package:flutter/material.dart';

import '../views/nhat_ky_he_thong/nhat_ky_he_thong_list_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view (không chứa logic).
class NhatKyHeThongPage extends StatelessWidget {
  const NhatKyHeThongPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký hệ thống')),
      body: const SafeArea(child: NhatKyHeThongListView()),
    );
  }
}
