import 'package:flutter/material.dart';

/// Bộ chọn giao diện sáng/tối/hệ thống. Component thuần giao diện — KHÔNG
/// đọc ThemeStore trực tiếp (component không được import stores/), giá
/// trị hiện tại và callback đổi giá trị truyền vào từ view bên ngoài
/// (xem views/settings/theme_mode_view.dart).
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Sáng'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Tối'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('Hệ thống'),
          icon: Icon(Icons.settings_suggest_outlined),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
