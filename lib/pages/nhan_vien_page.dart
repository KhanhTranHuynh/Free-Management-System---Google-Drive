import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../stores/auth_store.dart';

class NhanVienPage extends StatelessWidget {
  const NhanVienPage({super.key});

  @override
  Widget build(BuildContext context) {
    final coQuyenXem = context.watch<AuthStore>().coQuyen('NHAN_VIEN', 'xem');

    return Scaffold(
      body: Center(
        child: Text('coQuyen NHAN_VIEN xem: $coQuyenXem'),
      ),
    );
  }
}
