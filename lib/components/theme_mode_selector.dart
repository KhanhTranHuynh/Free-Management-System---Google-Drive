import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../stores/theme_store.dart';

class ThemeModeView extends StatelessWidget {
  const ThemeModeView({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeStore>().mode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero, // giãn đều hết chiều ngang
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Sáng'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Tối'),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.phone_android_outlined),
            label: Text('Hệ thống'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          context.read<ThemeStore>().setMode(selection.first);
        },
      ),
    );
  }
}
