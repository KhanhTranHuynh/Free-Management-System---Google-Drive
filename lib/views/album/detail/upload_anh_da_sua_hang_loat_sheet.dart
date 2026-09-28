import 'package:flutter/material.dart';

import '../../../../apis/services/album_detail_api.dart';
import '../../../../configs/app_colors.dart';

/// Tương ứng UploadAnhDaSuaHangLoatModal.jsx.
Future<void> hienUploadAnhDaSuaHangLoat(
  BuildContext context, {
  required AlbumDetailApi api,
  required String idAlbum,
  required List<Map<String, String>> lanChotOptions,
  required Future<void> Function() onUploaded,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _UploadBody(
      api: api,
      idAlbum: idAlbum,
      lanChotOptions: lanChotOptions,
      onUploaded: onUploaded,
    ),
  );
}

class _UploadBody extends StatefulWidget {
  const _UploadBody({
    required this.api,
    required this.idAlbum,
    required this.lanChotOptions,
    required this.onUploaded,
  });
  final AlbumDetailApi api;
  final String idAlbum;
  final List<Map<String, String>> lanChotOptions;
  final Future<void> Function() onUploaded;

  @override
  State<_UploadBody> createState() => _UploadBodyState();
}

class _UploadBodyState extends State<_UploadBody> {
  final _link = TextEditingController();
  String _lanChot = ''; // '' = tất cả các lần chốt
  bool _dang = false;
  ({int soThanhCong, List<String> khongKhop, List<String> duThua})? _kq;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  bool _laLinkDrive(String v) =>
      RegExp(r'^https?://.+', caseSensitive: false).hasMatch(v) &&
      (v.contains('drive.google.com') || v.contains('docs.google.com'));

  List<String> _strs(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : <String>[];

  Future<void> _luu() async {
    final link = _link.text.trim();
    if (link.isEmpty) return _msg('Vui lòng nhập link Google Drive');
    if (!_laLinkDrive(link)) {
      return _msg(
          'Link Google Drive không hợp lệ. Vui lòng nhập link thư mục Google Drive.');
    }
    if (_dang) return;
    setState(() {
      _dang = true;
      _kq = null;
    });
    try {
      final d = await widget.api.uploadKetQuaYeuCauChinhSua(
        idAlbum: widget.idAlbum,
        duongDanDrive: link,
        lanChotThu: _lanChot.isEmpty ? null : int.tryParse(_lanChot),
      );
      final soThanhCong = (d['so_luong_thanh_cong'] as num?)?.toInt() ?? 0;
      final khongKhop = _strs(d['khong_khop_trong_drive']);
      final duThua = _strs(d['du_thua_trong_drive']);
      _msg(soThanhCong > 0
          ? 'Đã ghi nhận kết quả cho $soThanhCong yêu cầu chỉnh sửa'
          : 'Không có ảnh nào khớp để ghi nhận kết quả');
      if (!mounted) return;
      setState(() => _kq = (
            soThanhCong: soThanhCong,
            khongKhop: khongKhop,
            duThua: duThua,
          ));
      await widget.onUploaded();
      // Mọi thứ khớp hết thì đóng luôn; còn thiếu/dư thì giữ lại để đọc.
      if (khongKhop.isEmpty && duThua.isEmpty && mounted) {
        Navigator.pop(context);
        return;
      }
    } catch (_) {
      _msg('Upload kết quả từ Google Drive thất bại');
    }
    if (mounted) setState(() => _dang = false);
  }

  Widget _hop(String tieuDe, Color mau, List<String> ds) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mau.withOpacity(0.08),
          border: Border.all(color: mau.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tieuDe,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: mau)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in ds)
                    Text('• $t', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Upload ảnh đã sửa',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  onPressed: _dang ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Dán link thư mục Google Drive đã bật chia sẻ "Bất kỳ ai có link", '
                'chứa ảnh đã sửa. Hệ thống tự so tên file với các yêu cầu chỉnh sửa '
                'ĐÃ CHỐT của album và đánh dấu hoàn thành cho những ảnh khớp tên.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              enabled: !_dang,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link thư mục Google Drive',
                hintText: 'https://drive.google.com/drive/folders/...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.lanChotOptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _lanChot,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Đối soát theo lần chốt',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('Tất cả các lần chốt')),
                  for (final o in widget.lanChotOptions)
                    DropdownMenuItem(
                        value: o['value'], child: Text(o['label'] ?? '')),
                ],
                onChanged:
                    _dang ? null : (v) => setState(() => _lanChot = v ?? ''),
              ),
            ],
            if (_kq != null) ...[
              _hop(
                  'Đã ghi nhận kết quả cho ${_kq!.soThanhCong} yêu cầu chỉnh sửa',
                  Colors.green.shade700, const []),
              if (_kq!.khongKhop.isNotEmpty)
                _hop(
                    'Đã chốt nhưng chưa tìm thấy trong Drive (${_kq!.khongKhop.length})',
                    Colors.amber.shade800,
                    _kq!.khongKhop),
              if (_kq!.duThua.isNotEmpty)
                _hop(
                    'Có trong Drive nhưng không khớp yêu cầu nào (${_kq!.duThua.length})',
                    Colors.blueGrey,
                    _kq!.duThua),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _dang ? null : () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: (_dang || _link.text.trim().isEmpty) ? null : _luu,
                  child: Text(
                      _dang ? 'Đang xử lý...' : 'Nhập ảnh từ Google Drive'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
