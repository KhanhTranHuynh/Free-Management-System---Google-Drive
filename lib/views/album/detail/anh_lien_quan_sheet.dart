import 'package:flutter/material.dart';

import '../../../../apis/services/tep_anh_api.dart';
import 'so_sanh_phien_ban.dart';

/// Tương ứng AnhLienQuanModal: ảnh cùng nhóm gốc/phiên bản (TepAnhApi.lienQuan).
Future<void> hienAnhLienQuan({
  required BuildContext context,
  required TepAnhApi api,
  required String idTepAnh,
  required ValueChanged<Map<String, dynamic>> onChon,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AnhLienQuanBody(
      api: api,
      idTepAnh: idTepAnh,
      onChon: (a) {
        Navigator.pop(ctx);
        onChon(a);
      },
    ),
  );
}

class _AnhLienQuanBody extends StatefulWidget {
  const _AnhLienQuanBody(
      {required this.api, required this.idTepAnh, required this.onChon});
  final TepAnhApi api;
  final String idTepAnh;
  final ValueChanged<Map<String, dynamic>> onChon;

  @override
  State<_AnhLienQuanBody> createState() => _AnhLienQuanBodyState();
}

class _AnhLienQuanBodyState extends State<_AnhLienQuanBody> {
  late final Future<List<Map<String, dynamic>>> _f =
      widget.api.lienQuan(idTepAnh: widget.idTepAnh);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Ảnh liên quan',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _f,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return const Center(
                        child: Text('Không tải được ảnh liên quan.'));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Text('Không có ảnh liên quan.'));
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final url = a['duong_dan_preview']?.toString() ??
                          a['duong_dan_drive_xem']?.toString();
                      return GestureDetector(
                        onTap: () => widget.onChon(a),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(fit: StackFit.expand, children: [
                            Container(
                              color: Colors.grey.shade200,
                              child: url != null
                                  ? Image.network(url, fit: BoxFit.cover)
                                  : const Icon(Icons.image, color: Colors.grey),
                            ),
                            Positioned(
                              left: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999)),
                                child: Text(nhanVer(a),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 9)),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
