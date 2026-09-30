import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../apis/services/album_detail_api.dart';
import '../../../../configs/app_colors.dart';
import '../../../utils/tai_anh_util.dart';

/// Tương ứng DoiChieuXuatAnhModal.jsx.
Future<void> hienDoiChieuXuatAnh(
  BuildContext context, {
  required AlbumDetailApi api,
  required String idAlbum,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DoiChieuBody(api: api, idAlbum: idAlbum),
  );
}

class _DoiChieuBody extends StatefulWidget {
  const _DoiChieuBody({required this.api, required this.idAlbum});
  final AlbumDetailApi api;
  final String idAlbum;

  @override
  State<_DoiChieuBody> createState() => _DoiChieuBodyState();
}

class _DoiChieuBodyState extends State<_DoiChieuBody> {
  bool _nguonDrive = true;
  bool _dang = false;
  String _tienDo = '';

  // --- Drive ---
  final _link = TextEditingController();
  Map<String, dynamic>? _kq;

  // --- Ảnh trên máy ---
  List<PlatformFile> _files = [];
  List<Map<String, dynamic>> _daChot = [];
  bool _daTaiDaChot = false;

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

  List<Map<String, dynamic>> _ds(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  // ---------------- Drive ----------------
  Future<void> _doiChieuDrive() async {
    final link = _link.text.trim();
    if (link.isEmpty) return _msg('Vui lòng dán link thư mục Google Drive');
    setState(() => _dang = true);
    try {
      final kq = await widget.api
          .doiChieuAlbum(idAlbum: widget.idAlbum, duongDanDrive: link);
      if (!mounted) return;
      setState(() => _kq = kq);
      if (_ds(kq['khop']).isEmpty) {
        _msg('Không có ảnh nào khớp tên với thư mục Drive này');
      }
    } catch (_) {
      _msg('Đối chiếu thất bại');
    }
    if (mounted) setState(() => _dang = false);
  }

  Future<void> _taiDrive() async {
    final khop = _ds(_kq?['khop']);
    if (khop.isEmpty || _dang) return;
    setState(() {
      _dang = true;
      _tienDo = 'Đang tải 0/${khop.length} từ Drive...';
    });
    try {
      final loi = await TaiAnh.taiNhieuTuDrive(khop, (d, t) {
        if (mounted) setState(() => _tienDo = 'Đang tải $d/$t từ Drive...');
      });
      if (loi > 0) {
        _msg(
            'Bỏ qua $loi file tải lỗi từ Google Drive (có thể đã tắt chia sẻ)');
      }
    } catch (_) {
      _msg('Xuất file thất bại');
    }
    if (mounted) {
      setState(() {
        _dang = false;
        _tienDo = '';
      });
    }
  }

  // ---------------- Ảnh trên máy ----------------
  Future<void> _taiDaChot({bool ep = false}) async {
    if (_daTaiDaChot && !ep) return;
    setState(() => _dang = true);
    try {
      final ds = await widget.api.danhSachDaChot(widget.idAlbum);
      if (!mounted) return;
      setState(() {
        _daChot = ds;
        _daTaiDaChot = true;
      });
      if (ds.isEmpty) _msg('Album này chưa có ảnh nào đã chốt');
    } catch (_) {
      _msg('Tải danh sách ảnh đã chốt thất bại');
    }
    if (mounted) setState(() => _dang = false);
  }

  Future<void> _chonFile() async {
    final r = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (r.isEmpty || !mounted) return;
    setState(() => _files = r.where((f) => f.path != null).toList());
  }

  static String _boDuoi(String s) {
    final i = s.lastIndexOf('.');
    return i > 0 ? s.substring(0, i) : s;
  }

  /// doiChieuAnhVaFile: khớp tên (bỏ đuôi, phân biệt hoa/thường).
  ({
    List<({Map<String, dynamic> anh, List<PlatformFile> files})> khop,
    List<Map<String, dynamic>> thieu,
    List<PlatformFile> du,
  }) _soKhop() {
    final theoTen = <String, List<PlatformFile>>{};
    for (final f in _files) {
      (theoTen[_boDuoi(f.name)] ??= []).add(f);
    }
    final khop = <({Map<String, dynamic> anh, List<PlatformFile> files})>[];
    final thieu = <Map<String, dynamic>>[];
    final daDung = <String>{};
    for (final a in _daChot) {
      final k = _boDuoi(a['ten_tep_goc']?.toString() ?? '');
      final fs = theoTen[k];
      if (fs != null && fs.isNotEmpty) {
        khop.add((anh: a, files: fs));
        daDung.add(k);
      } else {
        thieu.add(a);
      }
    }
    final du = _files.where((f) => !daDung.contains(_boDuoi(f.name))).toList();
    return (khop: khop, thieu: thieu, du: du);
  }

  Future<void> _chiaSeMay(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await TaiAnh.chiaSe(paths);
    } catch (_) {
      _msg('Xuất file thất bại');
    }
  }

  // ---------------- UI ----------------
  Widget _nhom(String tieuDe, Color mau, List<(String, String?)> items,
      {double maxH = 180}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tieuDe,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: mau)),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('Không có mục nào.',
                style: TextStyle(fontSize: 11, color: Colors.grey))
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          if (it.$2 != null)
                            Text(it.$2!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrive() {
    final khop = _ds(_kq?['khop']);
    final thieu = _ds(_kq?['thieu_trong_drive']);
    final du = _ds(_kq?['du_trong_drive']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dán link thư mục Google Drive (đã bật chia sẻ "Bất kỳ ai có link") — '
          'hệ thống đối chiếu tên file (bỏ đuôi, phân biệt hoa/thường) với ảnh '
          'đã được yêu cầu chỉnh sửa trong album. Chỉ file khớp tên mới được tải.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        if (_kq == null)
          Row(children: [
            Expanded(
              child: TextField(
                controller: _link,
                enabled: !_dang,
                decoration: const InputDecoration(
                  hintText: 'https://drive.google.com/drive/folders/...',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _dang ? null : _doiChieuDrive,
              child: Text(_dang ? 'Đang đối chiếu...' : 'Đối chiếu'),
            ),
          ])
        else ...[
          Row(children: [
            Expanded(
                child: Text(_link.text,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton(
              onPressed: _dang
                  ? null
                  : () => setState(() {
                        _kq = null;
                        _link.clear();
                      }),
              child: const Text('Đổi link'),
            ),
          ]),
          _nhom('Khớp — sẽ được tải (${khop.length})', Colors.green.shade700, [
            for (final k in khop)
              (
                k['ten_tep_goc']?.toString() ?? '—',
                'File Drive: ${k['ten_tep_goc_drive'] ?? ''}'
                    '${(k['so_file_trung_ten'] as num? ?? 0) > 1 ? ' • Trùng x${k['so_file_trung_ten']}' : ''}'
              )
          ]),
          if (thieu.isNotEmpty)
            _nhom(
                'Chưa có trên Drive (${thieu.length})',
                Colors.red.shade700,
                [
                  for (final k in thieu)
                    (k['ten_tep_goc']?.toString() ?? '—', null)
                ],
                maxH: 140),
          if (du.isNotEmpty)
            _nhom(
                'Ảnh dư trên Drive — không khớp yêu cầu nào (${du.length})',
                Colors.blueGrey,
                [
                  for (final k in du)
                    (k['ten_tep_goc']?.toString() ?? '—', null)
                ],
                maxH: 140),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: (khop.isEmpty || _dang) ? null : _taiDrive,
            icon: const Icon(Icons.download, size: 16),
            label: Text(_dang && _tienDo.isNotEmpty ? _tienDo : 'Tải ảnh về'),
          ),
        ],
      ],
    );
  }

  Widget _buildMay() {
    final r = _soKhop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn ảnh trên máy — hệ thống tự đối chiếu tên file (bỏ đuôi, phân biệt '
          'hoa/thường) với toàn bộ ảnh ĐÃ CHỐT trong album. Chỉ file khớp tên mới '
          'được xuất.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(
              _daChot.isEmpty
                  ? (_dang
                      ? 'Đang tải danh sách ảnh đã chốt...'
                      : 'Chưa tải được danh sách ảnh đã chốt')
                  : 'Album có ${_daChot.length} ảnh đã chốt',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: _dang ? null : () => _taiDaChot(ep: true),
            child: const Text('Tải lại danh sách'),
          ),
        ]),
        OutlinedButton.icon(
          onPressed: _dang ? null : _chonFile,
          icon: const Icon(Icons.photo_library_outlined, size: 16),
          label: Text(_files.isEmpty
              ? 'Chọn ảnh trên máy'
              : 'Đã chọn ${_files.length} ảnh — chọn lại'),
        ),
        if (_files.isNotEmpty && _daChot.isNotEmpty) ...[
          _nhom(
              'Khớp — sẽ được xuất (${r.khop.length})', Colors.green.shade700, [
            for (final k in r.khop)
              (
                k.anh['ten_tep_goc']?.toString() ?? '—',
                'File: ${k.files.first.name}'
                    '${k.files.length > 1 ? ' • Trùng x${k.files.length}' : ''}'
              )
          ]),
          if (r.thieu.isNotEmpty)
            _nhom(
                'Chưa có trong ảnh đã chọn (${r.thieu.length})',
                Colors.red.shade700,
                [
                  for (final a in r.thieu)
                    (a['ten_tep_goc']?.toString() ?? '—', null)
                ],
                maxH: 140),
          if (r.du.isNotEmpty)
            _nhom('Ảnh dư — không thuộc danh sách đã chốt (${r.du.length})',
                Colors.blueGrey, [for (final f in r.du) (f.name, null)],
                maxH: 140),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: r.khop.isEmpty
                ? null
                : () => _chiaSeMay([
                      for (final k in r.khop) k.files.first.path!,
                    ]),
            icon: const Icon(Icons.ios_share, size: 16),
            label: const Text('Xuất ảnh khớp'),
          ),
        ],
        if (_files.isNotEmpty && !_dang && _daTaiDaChot && _daChot.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
                'Album này chưa có ảnh nào đã chốt — chưa có gì để đối chiếu.',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Đối chiếu & xuất ảnh',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Link Google Drive')),
                ButtonSegment(value: false, label: Text('Ảnh trên máy')),
              ],
              selected: {_nguonDrive},
              onSelectionChanged: _dang
                  ? null
                  : (s) {
                      setState(() => _nguonDrive = s.first);
                      if (!s.first) _taiDaChot();
                    },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: _nguonDrive ? _buildDrive() : _buildMay(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
