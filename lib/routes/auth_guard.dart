import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/login_page.dart';
import '../stores/auth_store.dart';

/// Bọc quanh page cần đăng nhập. Nếu AuthStore chưa có nguoiDung (chưa
/// đăng nhập), hiển thị LoginPage thay vì page được bảo vệ.
class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthStore>().isLoggedIn;
    if (!isLoggedIn) return const LoginPage();
    return child;
  }
}
