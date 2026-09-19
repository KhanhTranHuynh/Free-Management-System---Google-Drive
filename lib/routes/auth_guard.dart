import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/login_page.dart';
import '../stores/auth_store.dart';

/// Bọc quanh trang cần đăng nhập. Chưa đăng nhập thì hiện trang login.
class AuthGuard extends StatelessWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthStore>().isLoggedIn;
    return isLoggedIn ? child : const LoginPage();
  }
}
