import 'package:flutter/material.dart';

import '../danh_muc_khach_hang/danh_muc_khach_hang_list_view.dart';
import '../tai_khoan_khach_hang/tai_khoan_khach_hang_list_view.dart';

/// Gộp 2 tab "Danh Mục Khách Hàng" và "Khách hàng" vào 1 view duy nhất,
/// không dùng Scaffold/AppBar riêng để tránh dư khoảng trắng với header
/// có sẵn ở khung ngoài (shell) của app — theo đúng pattern NhanVienPage.
class KhachHangListView extends StatefulWidget {
  const KhachHangListView({super.key});

  @override
  State<KhachHangListView> createState() => _KhachHangListViewState();
}

class _KhachHangListViewState extends State<KhachHangListView>
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
    return Column(
      children: [
        TabBar(
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
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              DanhMucKhachHangListView(),
              TaiKhoanKhachHangListView(),
            ],
          ),
        ),
      ],
    );
  }
}
