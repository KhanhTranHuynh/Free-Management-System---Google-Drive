import 'package:flutter/material.dart';

import '../views/danh_muc_khach_hang/danh_muc_khach_hang_list_view.dart';
import '../views/khach_hang/khach_hang_list_view.dart';

/// Trang "Khách hàng" — khung mỏng (Scaffold + AppBar + SafeArea, khớp mẫu
/// NhanVienPage), ghép 2 view qua Tab, không chứa logic riêng. Tương đương
/// bản React KhachHangPage.jsx (TabsWithIcon với 2 tab: "Danh Mục Khách
/// Hàng" / "Khách hàng").
class KhachHangPage extends StatefulWidget {
  const KhachHangPage({super.key});

  @override
  State<KhachHangPage> createState() => _KhachHangPageState();
}

class _KhachHangPageState extends State<KhachHangPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (title: 'Danh Mục Khách Hàng', icon: Icons.groups_outlined),
    (title: 'Khách hàng', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final t in _tabs)
              Tab(
                icon: Icon(t.icon, size: 18),
                text: t.title,
                iconMargin: const EdgeInsets.only(bottom: 4),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            DanhMucKhachHangListView(),
            KhachHangListView(),
          ],
        ),
      ),
    );
  }
}
