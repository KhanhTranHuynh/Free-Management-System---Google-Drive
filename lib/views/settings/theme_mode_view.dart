import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../stores/theme_store.dart';

class ThemeModeView extends StatelessWidget {
  const ThemeModeView({super.key});

  static const _options = [
    (ThemeMode.light, 'Sáng', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Tối', Icons.dark_mode_outlined),
    (ThemeMode.system, 'Theo hệ thống', Icons.phone_android_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final current = context.watch<ThemeStore>().mode;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Giao diện',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final (mode, label, icon) in _options)
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: mode == current
                ? Icon(Icons.check, color: scheme.primary)
                : null,
            selected: mode == current,
            onTap: () => context.read<ThemeStore>().setMode(mode),
          ),
      ],
    );
  }
}
