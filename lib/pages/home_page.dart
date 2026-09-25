import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../configs/app_spacing.dart';
import '../routes/app_routes.dart';
import '../stores/auth_store.dart';
import '../views/home/home_header_view.dart';
import '../views/home/user_info_view.dart';

/// Trang chủ — hiển thị toàn bộ dữ liệu đang lưu trong AuthStore sau khi
/// đăng nhập thành công. Page mỏng: chỉ dựng khung + ghép views.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _dangXuat(BuildContext context) async {
    await context.read<AuthStore>().dangXuat();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _dangXuat(context),
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeHeaderView(),
            SizedBox(height: AppSpacing.lg),
            UserInfoView(),
          ],
        ),
      ),
    );
  }
}
