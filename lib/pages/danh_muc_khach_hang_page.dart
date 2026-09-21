import 'package:flutter/material.dart';

import '../views/danh_muc_khach_hang/danh_muc_khach_hang_list_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view.
class DanhMucKhachHangPage extends StatelessWidget {
  const DanhMucKhachHangPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục khách hàng')),
      body: const SafeArea(child: DanhMucKhachHangListView()),
    );
  }
}
