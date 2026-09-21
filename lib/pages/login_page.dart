import 'package:flutter/material.dart';

import '../configs/app_spacing.dart';
import '../views/auth/login_form_view.dart';

/// Trang đăng nhập. Page mỏng: chỉ dựng khung + ghép view, không chứa
/// logic gọi API hay quản lý state chi tiết (nằm ở LoginFormView/AuthStore).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_back_outlined, size: 56),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Đăng nhập',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const LoginFormView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
