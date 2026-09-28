import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

/// Khớp urlTaiGocTuDrive bên React.
String urlTaiGocTuDrive(String fileId) =>
    'https://drive.google.com/uc?export=download&id=$fileId';

String? urlXemCuaAnh(Map<String, dynamic>? a) =>
    a?['duong_dan_preview']?.toString() ??
    a?['duong_dan_drive_xem']?.toString();

/// Giống nhánh chọn URL trong handleTaiAnh / handleTaiXuong của React.
String? urlTaiCuaAnh(Map<String, dynamic> a) {
  final fileId = a['file_id_drive']?.toString();
  final drive = a['duong_dan_drive_xem']?.toString();
  if (drive != null && drive.isNotEmpty) {
    return (fileId != null && fileId.isNotEmpty)
        ? urlTaiGocTuDrive(fileId)
        : drive;
  }
  return urlXemCuaAnh(a);
}

/// Tải file về thư mục tạm rồi mở share sheet (tương ứng
/// taiMotFileVoiXuLyZalo / xuatTuanTuKieuZalo bên React).
class TaiAnh {
  static String _tenAnToan(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  static Future<File> _taiVe(String url, String ten, Directory dir) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final f = File('${dir.path}/${_tenAnToan(ten)}');
    await f.writeAsBytes(res.bodyBytes);
    return f;
  }

  static Future<void> chiaSe(List<String> paths) async {
    if (paths.isEmpty) return;
    await Share.shareXFiles([for (final p in paths) XFile(p)]);
  }

  /// Tải + chia sẻ 1 ảnh. Trả về false nếu không có URL.
  static Future<bool> taiMotAnh(Map<String, dynamic> anh) async {
    final url = urlTaiCuaAnh(anh);
    if (url == null) return false;
    final ten = anh['ten_tep_goc']?.toString() ?? 'IMG_${anh['id_tep_anh']}';
    final dir = await Directory.systemTemp.createTemp('album_');
    final f = await _taiVe(url, ten, dir);
    await chiaSe([f.path]);
    return true;
  }

  /// items: [{file_id_drive, ten_tep_goc, ten_tep_goc_drive?}].
  /// Tải song song 4 luồng (giống React), rồi chia sẻ 1 lần.
  /// Trả về số file lỗi.
  static Future<int> taiNhieuTuDrive(
    List<Map<String, dynamic>> items,
    void Function(int daXong, int tongSo)? onTienDo,
  ) async {
    final dir = await Directory.systemTemp.createTemp('album_');
    final ketQua = List<File?>.filled(items.length, null);
    var idx = 0;
    var daXong = 0;

    Future<void> luong() async {
      while (idx < items.length) {
        final i = idx++;
        final it = items[i];
        try {
          final id = it['file_id_drive']?.toString() ?? '';
          final ten = (it['ten_tep_goc_drive'] ?? it['ten_tep_goc'] ?? 'anh_$i')
              .toString();
          ketQua[i] = await _taiVe(urlTaiGocTuDrive(id), '${i}_$ten', dir);
        } catch (_) {}
        daXong++;
        onTienDo?.call(daXong, items.length);
      }
    }

    final soLuong = items.length < 4 ? items.length : 4;
    await Future.wait(List.generate(soLuong, (_) => luong()));
    final ok = ketQua.whereType<File>().toList();
    await chiaSe(ok.map((f) => f.path).toList());
    return items.length - ok.length;
  }
}

/// Xem ảnh toàn màn hình (thay ImageGalleryModal): vuốt qua lại, zoom.
Future<void> hienXemAnhToanManHinh(
  BuildContext context, {
  required List<Map<String, dynamic>> ds,
  required int batDau,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _XemAnhToanManHinh(ds: ds, batDau: batDau),
  ));
}

class _XemAnhToanManHinh extends StatefulWidget {
  const _XemAnhToanManHinh({required this.ds, required this.batDau});
  final List<Map<String, dynamic>> ds;
  final int batDau;

  @override
  State<_XemAnhToanManHinh> createState() => _XemAnhToanManHinhState();
}

class _XemAnhToanManHinhState extends State<_XemAnhToanManHinh> {
  late final PageController _pc = PageController(initialPage: widget.batDau);
  late int _i = widget.batDau;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ds[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${a['ten_tep_goc'] ?? '—'}  (${_i + 1}/${widget.ds.length})',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.ds.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (_, i) {
          final url = urlXemCuaAnh(widget.ds[i]);
          return InteractiveViewer(
            child: Center(
              child: url == null
                  ? const Icon(Icons.broken_image, color: Colors.white54)
                  : Image.network(url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white54)),
            ),
          );
        },
      ),
    );
  }
}
