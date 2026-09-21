import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/theme_mode_selector.dart';
import '../../stores/theme_store.dart';

/// View đọc/ghi ThemeStore rồi truyền giá trị xuống ThemeModeSelector
/// (component thuần, không được phép import stores/ trực tiếp).
class ThemeModeView extends StatelessWidget {
  const ThemeModeView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeStore = context.watch<ThemeStore>();

    return ThemeModeSelector(
      value: themeStore.mode,
      onChanged: (mode) => context.read<ThemeStore>().setMode(mode),
    );
  }
}
