import 'package:flutter/material.dart';

import '../../../../apis/services/yeu_cau_chinh_sua_api.dart';

/// Tương ứng UploadKetQuaChinhSuaModal: dán link 1 file ảnh Drive đã sửa.
/// Trả về true nếu upload thành công.
Future<bool> hienUploadKetQua({
  required BuildContext context,
  required YeuCauChinhSuaApi api,
  required Map<String, dynamic> yeuCau,
}) async {
  final ctrl = TextEditingController();
  var dang = false;
  String? loi;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title:
            Text('Upload ảnh đã sửa (lần ${yeuCau['lan_chinh_sua'] ?? '?'})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((yeuCau['noi_dung_yeu_cau']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Yêu cầu: ${yeuCau['noi_dung_yeu_cau']}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ),
            TextField(
              controller: ctrl,
              enabled: !dang,
              decoration: const InputDecoration(
                labelText: 'Link Google Drive ảnh đã sửa xong',
                hintText: 'https://drive.google.com/file/d/...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Link phải trỏ tới đúng 1 file ảnh (không phải thư mục) và đã bật chia sẻ "Bất kỳ ai có link".',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (loi != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(loi!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: dang ? null : () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: dang
                ? null
                : () async {
                    final link = ctrl.text.trim();
                    if (link.isEmpty) {
                      setS(() => loi =
                          'Vui lòng dán link Google Drive của ảnh đã sửa');
                      return;
                    }
                    setS(() {
                      dang = true;
                      loi = null;
                    });
                    try {
                      await api.uploadKetQua(
                        idYeuCau: yeuCau['id_yeu_cau_chinh_sua'].toString(),
                        duongDanDrive: link,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setS(() {
                        dang = false;
                        loi = 'Ghi nhận ảnh đã sửa thất bại';
                      });
                    }
                  },
            child: Text(dang ? 'Đang ghi nhận...' : 'Lưu'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return ok == true;
}
