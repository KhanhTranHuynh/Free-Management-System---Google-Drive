import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Util dùng chung cho phần "màu hiển thị trên lịch" (mau_sac) — tách ra
/// từ 2 nơi từng lặp code: modal Sửa thông tin cá nhân
/// (sua_thong_tin_modal.dart) và modal Thêm nhân viên (add_nhan_vien.dart).
/// Gồm: bảng màu preset, parse/format hex <-> Color, validate hex, và
/// widget UI chọn màu (swatch tròn + optional nút "+" mở bánh xe màu tự
/// do) để 2 nơi (và các module sau này) dùng chung.

/// Bảng màu preset mặc định dùng chung toàn app. Truyền [mauSacGoiY]
/// riêng cho `MauSacGoiYPicker` nếu 1 màn hình cụ thể cần bảng khác.
const List<String> kMauSacGoiY = [
  '#6366F1', // indigo
  '#0EA5E9', // sky
  '#10B981', // emerald
  '#F59E0B', // amber
  '#EF4444', // red
  '#EC4899', // pink
  '#8B5CF6', // violet
  '#14B8A6', // teal
];

const String kMauSacMacDinh = '#6366F1';

final RegExp hexMauSacRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');

bool isHexMauSacHopLe(String hex) => hexMauSacRegex.hasMatch(hex.trim());

/// Parse chuỗi hex "#RRGGBB" -> Color. Nếu [hex] không hợp lệ (đang gõ
/// dở, rỗng...) thì trả về [fallback] thay vì crash.
Color hexToMauSac(String? hex, {String fallback = kMauSacMacDinh}) {
  final v = (hex ?? '').trim();
  final target = isHexMauSacHopLe(v) ? v : fallback;
  return Color(int.parse(
    'FF${target.replaceFirst('#', '').padLeft(6, '0')}',
    radix: 16,
  ));
}

/// Color -> chuỗi hex "#RRGGBB" viết hoa (dùng khi lấy màu từ bánh xe màu
/// tự do flutter_colorpicker).
String mauSacToHex(Color mau) {
  return ('#'
          '${mau.red.toRadixString(16).padLeft(2, '0')}'
          '${mau.green.toRadixString(16).padLeft(2, '0')}'
          '${mau.blue.toRadixString(16).padLeft(2, '0')}')
      .toUpperCase();
}

/// Widget dùng chung: hàng swatch tròn (bảng màu preset) + optional nút
/// "+" mở bánh xe màu tự do, tương đương `<input type="color">` bên web.
///
/// Dùng `HueRingPicker` (không dùng `ColorPicker` ô vuông HSV): ô vuông
/// HSV render sai gradient khi lồng trong AlertDialog +
/// SingleChildScrollView (mất lớp gradient theo hue).
class MauSacGoiYPicker extends StatelessWidget {
  const MauSacGoiYPicker({
    super.key,
    required this.mauSacDangChon,
    required this.onChon,
    this.mauSacGoiY = kMauSacGoiY,
    this.choPhepTuyChinh = false,
    this.disabled = false,
    this.swatchSize = 32,
  });

  /// Hex hiện đang chọn, để tô viền/dấu check cho swatch tương ứng.
  final String? mauSacDangChon;

  /// Gọi khi chọn 1 màu (preset hoặc tự chọn từ bánh xe) — trả về hex
  /// dạng "#RRGGBB" viết hoa.
  final ValueChanged<String> onChon;

  final List<String> mauSacGoiY;

  /// true: hiện thêm nút "+" mở bánh xe màu tự do.
  final bool choPhepTuyChinh;

  final bool disabled;
  final double swatchSize;

  void _moBanhXeMau(BuildContext context) {
    final mauHienTai = hexToMauSac(mauSacDangChon);
    Color mauDangChon = mauHienTai;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Chọn màu tuỳ chỉnh'),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 280,
            child: HueRingPicker(
              pickerColor: mauHienTai,
              onColorChanged: (mau) => mauDangChon = mau,
              displayThumbColor: true,
              enableAlpha: false,
              portraitOnly: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              onChon(mauSacToHex(mauDangChon));
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dangChonUpper = mauSacDangChon?.trim().toUpperCase();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in mauSacGoiY)
          _Swatch(
            hex: hex,
            size: swatchSize,
            dangChon: dangChonUpper == hex.toUpperCase(),
            onTap: disabled ? null : () => onChon(hex.toUpperCase()),
          ),
        if (choPhepTuyChinh)
          _NutTuyChinh(
            size: swatchSize,
            onTap: disabled ? null : () => _moBanhXeMau(context),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.dangChon,
    required this.onTap,
    required this.size,
  });

  final String hex;
  final bool dangChon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hexToMauSac(hex),
          shape: BoxShape.circle,
          border: Border.all(
            color:
                dangChon ? Colors.black.withOpacity(0.6) : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: dangChon
            ? Icon(Icons.check, size: size * 0.5, color: Colors.white)
            : null,
      ),
    );
  }
}

class _NutTuyChinh extends StatelessWidget {
  const _NutTuyChinh({required this.onTap, required this.size});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          gradient: const SweepGradient(
            colors: [
              Color(0xFFEF4444),
              Color(0xFFF59E0B),
              Color(0xFF10B981),
              Color(0xFF0EA5E9),
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
              Color(0xFFEF4444),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * 0.44,
          height: size * 0.44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add,
            size: size * 0.34,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
