import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../configs/app_spacing.dart';
import '../../routes/app_routes.dart';
import '../../stores/auth_store.dart';

class HomeHeaderView extends StatelessWidget {
  const HomeHeaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào aloalo, ${user?.name ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthStore>().logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
