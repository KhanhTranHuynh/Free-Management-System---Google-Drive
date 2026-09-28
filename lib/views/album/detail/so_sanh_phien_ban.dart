import 'package:flutter/material.dart';

import '../../../../configs/app_colors.dart';

String? _urlAnh(Map<String, dynamic>? a) =>
    a?['duong_dan_preview']?.toString() ??
    a?['duong_dan_drive_xem']?.toString();

String nhanVer(Map<String, dynamic>? a) {
  final lan = (a?['lan_sua_hien_tai'] as num?)?.toInt() ?? 0;
  return lan > 0 ? 'Ver $lan' : 'Ảnh gốc';
}

/// Cặp ảnh TRƯỚC / ĐÃ CHỈNH SỬA (dữ liệu từ TepAnhApi.keBen).
/// Có "sau" -> [hiện tại | sau]; chỉ có "trước" -> [trước | hiện tại].
class SoSanhPhienBan extends StatelessWidget {
  const SoSanhPhienBan({
    super.key,
    required this.anhHienTai,
    required this.truoc,
    required this.sau,
    required this.onXem,
    this.dangTai = false,
  });

  final Map<String, dynamic> anhHienTai;
  final Map<String, dynamic>? truoc;
  final Map<String, dynamic>? sau;
  final ValueChanged<Map<String, dynamic>> onXem;
  final bool dangTai;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? trai;
    final Map<String, dynamic>? phai;
    if (sau != null) {
      trai = anhHienTai;
      phai = sau;
    } else if (truoc != null) {
      trai = truoc;
      phai = anhHienTai;
    } else {
      return const SizedBox.shrink();
    }
    final idHienTai = anhHienTai['id_tep_anh']?.toString();

    Widget o(Map<String, dynamic>? a, String nhan) {
      final dangXem = a?['id_tep_anh']?.toString() == idHienTai;
      final url = _urlAnh(a);
      return Expanded(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.78,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: dangXem ? AppColors.primary : Colors.grey.shade300,
                      width: dangXem ? 2 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null) Image.network(url, fit: BoxFit.contain),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(nhanVer(a),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(nhan,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: dangXem ? AppColors.primary : Colors.grey)),
            if (!dangXem && a != null)
              TextButton(
                onPressed: () => onXem(a),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 24),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Xem', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(children: [
          o(trai, 'TRƯỚC CHỈNH SỬA'),
          const SizedBox(width: 12),
          o(phai, 'ĐÃ CHỈNH SỬA'),
        ]),
        if (dangTai)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Đang tải phiên bản liền kề...',
                style: TextStyle(fontSize: 9, color: Colors.grey)),
          ),
      ],
    );
  }
}
