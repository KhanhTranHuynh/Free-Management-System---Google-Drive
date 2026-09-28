import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../apis/services/binh_luan_anh_api.dart';
import '../../../../apis/services/tep_anh_api.dart';
import '../../../../apis/services/yeu_cau_chinh_sua_api.dart';
import '../../../../configs/app_colors.dart';
import 'album_detail_constants.dart';
import 'anh_lien_quan_sheet.dart';
import 'lich_su_yeu_cau_card.dart';
import 'so_sanh_phien_ban.dart';
import 'upload_ket_qua_dialog.dart';

/// Tương ứng DetailPanel.jsx (phiên bản mobile, bottom sheet).
///
/// Đã có: thông tin ảnh, danh sách yêu cầu, gửi yêu cầu (ẩn khi đã có
/// yêu cầu), bình luận dạng thread, gửi bình luận / trả lời.
/// Chưa có (cần thêm API): sửa/xoá yêu cầu, xoá / giải quyết bình luận,
/// hoàn thành yêu cầu, so sánh trước/sau (tepAnhKeBen), lịch sử yêu cầu,
/// ảnh liên quan, upload kết quả.
class AnhDetailSheet extends StatefulWidget {
  const AnhDetailSheet({
    super.key,
    required this.idAlbum,
    required this.anhBanDau,
    required this.tepAnhApi,
    required this.ycsApi,
    required this.blApi,
    required this.scrollController,
    required this.onThayDoi,
    this.quyen = const AlbumQuyen(),
  });

  final String idAlbum;
  final Map<String, dynamic> anhBanDau;
  final TepAnhApi tepAnhApi;
  final YeuCauChinhSuaApi ycsApi;
  final BinhLuanAnhApi blApi;
  final ScrollController scrollController;
  final Future<void> Function() onThayDoi;
  final AlbumQuyen quyen;

  @override
  State<AnhDetailSheet> createState() => _AnhDetailSheetState();
}

class _AnhDetailSheetState extends State<AnhDetailSheet> {
  final _yeuCauCtrl = TextEditingController();
  final _binhLuanCtrl = TextEditingController();

  Map<String, dynamic>? _chiTiet;
  bool _isLoading = true;
  bool _isError = false;
  bool _dangGuiYeuCau = false;
  bool _dangGuiBinhLuan = false;
  String? _dangTraLoiId;
  bool _moRongYeuCau = false;
  bool _moRongBinhLuan = false;

  // Ảnh đang xem trong sheet (đổi được khi bấm "Xem" ở cặp so sánh / ảnh liên quan).
  late Map<String, dynamic> _anhHienTai = widget.anhBanDau;
  Map<String, dynamic>? _keBen; // { truoc, sau }
  List<Map<String, dynamic>> _lichSu = [];
  bool _dangTaiPhuTro = false;
  bool _dangXoaYeuCau = false;

  String get _idTepAnh => _anhHienTai['id_tep_anh'].toString();

  @override
  void initState() {
    super.initState();
    unawaited(_taiChiTiet());
  }

  @override
  void dispose() {
    _yeuCauCtrl.dispose();
    _binhLuanCtrl.dispose();
    super.dispose();
  }

  // ---- gộp dữ liệu list + chi tiết (chi tiết không được ghi đè bằng null) ----
  Map<String, dynamic> get _anh {
    final ct = Map<String, dynamic>.from(
        (_chiTiet?['tep_anh'] as Map?) ?? const <String, dynamic>{});
    final merged = {..._anhHienTai};
    ct.forEach((k, v) {
      if (v != null) merged[k] = v;
    });
    return merged;
  }

  Future<void> _taiChiTiet() async {
    unawaited(_taiPhuTro());
    setState(() {
      _isLoading = _chiTiet == null;
      _isError = false;
    });
    try {
      final body = await widget.tepAnhApi.chiTiet(idTepAnh: _idTepAnh);
      if (!mounted) return;
      setState(() {
        _chiTiet = body;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
      });
    }
  }

  /// Phiên bản liền kề (keBen) + lịch sử yêu cầu. Lỗi ở đây không chặn panel.
  Future<void> _taiPhuTro() async {
    final id = _idTepAnh;
    setState(() => _dangTaiPhuTro = true);
    try {
      final kb = await widget.tepAnhApi.keBen(idTepAnh: id);
      if (mounted && id == _idTepAnh) setState(() => _keBen = kb);
    } catch (_) {
      if (mounted && id == _idTepAnh) setState(() => _keBen = null);
    }
    try {
      final ls = await widget.ycsApi.lichSu(idTepAnh: id);
      if (mounted && id == _idTepAnh) setState(() => _lichSu = ls);
    } catch (_) {}
    if (mounted) setState(() => _dangTaiPhuTro = false);
  }

  void _chuyenAnh(Map<String, dynamic> a) {
    if (a['id_tep_anh'] == null) return;
    setState(() {
      _anhHienTai = a;
      _chiTiet = null;
      _keBen = null;
      _lichSu = [];
      _dangTraLoiId = null;
    });
    unawaited(_taiChiTiet());
  }

  Future<void> _suaYeuCau(String id, String noiDung) async {
    try {
      await widget.ycsApi.sua(idYeuCau: id, noiDung: noiDung);
      _msg('Đã cập nhật nội dung yêu cầu chỉnh sửa');
      await _taiChiTiet();
    } catch (_) {
      _msg('Cập nhật yêu cầu chỉnh sửa thất bại');
      rethrow;
    }
  }

  Future<void> _xoaYeuCau() async {
    if (_dangXoaYeuCau) return;
    setState(() => _dangXoaYeuCau = true);
    try {
      await widget.ycsApi.xoaChuaChotTheoTepAnh(idTepAnh: _idTepAnh);
      _msg('Đã xóa yêu cầu chỉnh sửa');
      await _taiChiTiet();
      await widget.onThayDoi();
    } catch (_) {
      _msg('Xóa yêu cầu chỉnh sửa thất bại');
    } finally {
      if (mounted) setState(() => _dangXoaYeuCau = false);
    }
  }

  Future<void> _upload(Map<String, dynamic> y) async {
    final ok = await hienUploadKetQua(
      context: context,
      api: widget.ycsApi,
      yeuCau: {...y, 'tep_anh_id': _idTepAnh},
    );
    if (ok) {
      _msg('Đã ghi nhận ảnh đã sửa');
      await _taiChiTiet();
      await widget.onThayDoi();
    }
  }

  void _msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _guiYeuCau() async {
    final noiDung = _yeuCauCtrl.text.trim();
    if (noiDung.isEmpty || _dangGuiYeuCau) return;
    setState(() => _dangGuiYeuCau = true);
    try {
      await widget.ycsApi.taoHangLoat(
        idAlbum: widget.idAlbum,
        tepAnhIds: [_idTepAnh],
        noiDung: noiDung,
      );
      _yeuCauCtrl.clear();
      _msg('Đã gửi yêu cầu chỉnh sửa');
      await _taiChiTiet();
      await widget.onThayDoi();
    } catch (_) {
      _msg('Gửi yêu cầu thất bại, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _dangGuiYeuCau = false);
    }
  }

  Future<void> _guiBinhLuan() async {
    final noiDung = _binhLuanCtrl.text.trim();
    if (noiDung.isEmpty || _dangGuiBinhLuan) return;
    setState(() => _dangGuiBinhLuan = true);
    try {
      // TODO: blApi.taoBinhLuan cần nhận thêm binhLuanChaId (trả lời).
      await widget.blApi.taoBinhLuan(idTepAnh: _idTepAnh, noiDung: noiDung);
      _binhLuanCtrl.clear();
      setState(() => _dangTraLoiId = null);
      await _taiChiTiet();
    } catch (_) {
      _msg('Gửi bình luận thất bại, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _dangGuiBinhLuan = false);
    }
  }

  // ---- gom thread bình luận (giống gomThreadBinhLuan) ----
  List<({Map<String, dynamic> root, List<Map<String, dynamic>> traLoi})>
      _gomThread(List<Map<String, dynamic>> list) {
    final ids = list.map((e) => e['id_binh_luan_anh']?.toString()).toSet();
    final conCuaCha = <String, List<Map<String, dynamic>>>{};
    final goc = <Map<String, dynamic>>[];
    for (final bl in list) {
      final cha = bl['binh_luan_cha_id']?.toString();
      if (cha != null && ids.contains(cha)) {
        (conCuaCha[cha] ??= []).add(bl);
      } else {
        goc.add(bl);
      }
    }
    DateTime t(Map<String, dynamic> m) =>
        DateTime.tryParse(m['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    List<Map<String, dynamic>> duyet(String id) {
      final con = [...(conCuaCha[id] ?? [])]
        ..sort((a, b) => t(a).compareTo(t(b)));
      return [
        for (final c in con) ...[c, ...duyet(c['id_binh_luan_anh'].toString())]
      ];
    }

    final threads = goc
        .map((r) => (root: r, traLoi: duyet(r['id_binh_luan_anh'].toString())))
        .toList();
    DateTime moiNhat(
            ({
              Map<String, dynamic> root,
              List<Map<String, dynamic>> traLoi
            }) th) =>
        [th.root, ...th.traLoi].map(t).reduce((a, b) => a.isAfter(b) ? a : b);
    threads.sort((a, b) => moiNhat(b).compareTo(moiNhat(a)));
    return threads;
  }

  String _fmt(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final anh = _anh;
    final lanSua = (anh['lan_sua_hien_tai'] as num?)?.toInt() ?? 0;

    final yeuCau = List<Map<String, dynamic>>.from(
        _chiTiet?['yeu_cau_chinh_sua'] as List? ?? [])
      ..sort((a, b) => (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString()));
    final binhLuan =
        List<Map<String, dynamic>>.from(_chiTiet?['binh_luan'] as List? ?? []);
    final threads = _gomThread(binhLuan);

    final yeuCauCuaAnh =
        yeuCau.where((y) => y['tep_anh_id']?.toString() == _idTepAnh).toList();
    final daCoYeuCau = yeuCauCuaAnh.isNotEmpty;

    final yeuCauHienThi = _moRongYeuCau ? yeuCau : yeuCau.take(1).toList();
    final threadHienThi = _moRongBinhLuan ? threads : threads.take(1).toList();

    final url = anh['duong_dan_preview']?.toString() ??
        anh['duong_dan_drive_xem']?.toString();

    Map<String, dynamic>? layKe(String k) =>
        _keBen?[k] is Map ? Map<String, dynamic>.from(_keBen![k] as Map) : null;
    final verTruoc = layKe('truoc');
    final verSau = layKe('sau');
    final coSoSanh = verTruoc != null || verSau != null;
    final laAnhDaChinhSua = lanSua > 0 || verTruoc != null;
    final yeuCauCoTheUpload = yeuCauCuaAnh
        .where((y) => y['trang_thai_yeu_cau'] != 'hoan_thanh')
        .firstOrNull;
    final coTheUpload = widget.quyen.laNhanVien &&
        anh['duoc_phep_upload_ket_qua'] == true &&
        yeuCauCoTheUpload != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chi tiết ảnh',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          if (coSoSanh)
            SoSanhPhienBan(
              anhHienTai: anh,
              truoc: verTruoc,
              sau: verSau,
              dangTai: _dangTaiPhuTro,
              onXem: _chuyenAnh,
            )
          else if (url != null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              if (coTheUpload)
                OutlinedButton.icon(
                  onPressed: () => _upload(yeuCauCoTheUpload!),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 14),
                  label: const Text('Upload kết quả'),
                ),
              OutlinedButton.icon(
                onPressed: () => hienAnhLienQuan(
                  context: context,
                  api: widget.tepAnhApi,
                  idTepAnh: _idTepAnh,
                  onChon: _chuyenAnh,
                ),
                icon: const Icon(Icons.image_outlined, size: 14),
                label: const Text('Ảnh liên quan'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Section(
            title: 'Thông tin tệp ảnh',
            child: Column(children: [
              _Row('Tên tệp gốc', anh['ten_tep_goc']?.toString() ?? '—'),
              _Row('Trạng thái',
                  _tenTrangThai(anh['trang_thai_anh']?.toString())),
              _Row('Phiên bản', lanSua > 0 ? 'Sửa lần $lanSua' : 'Gốc'),
              _Row('Ngày tạo', _fmt(anh['created_at'])),
            ]),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_isError)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('Không tải được chi tiết ảnh.',
                    style: TextStyle(color: cs.error)),
                TextButton(
                    onPressed: _taiChiTiet, child: const Text('Thử lại')),
              ]),
            )
          else ...[
            // ================= YÊU CẦU CHỈNH SỬA =================
            _Section(
              title: 'Yêu cầu chỉnh sửa',
              trailing: '${yeuCau.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (yeuCau.isEmpty)
                    Text('Chưa có yêu cầu chỉnh sửa nào.',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                  ...yeuCauHienThi.map((y) {
                    final chuaChot = y['trang_thai_yeu_cau'] == 'da_yeu_cau';
                    return _YeuCauCard(
                      y: y,
                      fmt: _fmt,
                      onSua: (widget.quyen.suaYeuCau && chuaChot)
                          ? _suaYeuCau
                          : null,
                      onXoa: (widget.quyen.huyYeuCau &&
                              anh['duoc_phep_huy_yeu_cau'] == true &&
                              chuaChot)
                          ? _xoaYeuCau
                          : null,
                      dangXoa: _dangXoaYeuCau,
                    );
                  }),
                  _XemThem(
                    dangMoRong: _moRongYeuCau,
                    soAn: yeuCau.length - 1,
                    onToggle: () =>
                        setState(() => _moRongYeuCau = !_moRongYeuCau),
                  ),
                  if (daCoYeuCau)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ảnh đã có yêu cầu chỉnh sửa. Chỉ được sửa/xóa yêu cầu khi chưa chốt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                    )
                  else if (widget.quyen.taoYeuCau)
                    _InputRow(
                      controller: _yeuCauCtrl,
                      hint: 'Nhập nội dung yêu cầu chỉnh sửa...',
                      dangGui: _dangGuiYeuCau,
                      onSend: _guiYeuCau,
                    ),
                ],
              ),
            ),
            // ================= BÌNH LUẬN =================
            _Section(
              title: 'Bình luận',
              trailing: '${binhLuan.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (binhLuan.isEmpty)
                    Text('Chưa có bình luận nào.',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                  ...threadHienThi.map((th) => Column(
                        children: [
                          _BinhLuanCard(
                              bl: th.root,
                              fmt: _fmt,
                              onReply: () => setState(() {
                                    _dangTraLoiId =
                                        th.root['id_binh_luan_anh'].toString();
                                    _moRongBinhLuan = true;
                                  })),
                          ...th.traLoi.map((r) => _BinhLuanCard(
                                bl: r,
                                fmt: _fmt,
                                isReply: true,
                                onReply: () => setState(() => _dangTraLoiId =
                                    r['id_binh_luan_anh'].toString()),
                              )),
                        ],
                      )),
                  _XemThem(
                    dangMoRong: _moRongBinhLuan,
                    soAn: threads.length - 1,
                    onToggle: () =>
                        setState(() => _moRongBinhLuan = !_moRongBinhLuan),
                  ),
                  if (_dangTraLoiId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.reply, size: 14),
                          const SizedBox(width: 6),
                          const Expanded(
                              child: Text('Đang trả lời 1 bình luận',
                                  style: TextStyle(fontSize: 11))),
                          InkWell(
                            onTap: () => setState(() => _dangTraLoiId = null),
                            child: const Icon(Icons.close, size: 14),
                          ),
                        ],
                      ),
                    ),
                  _InputRow(
                    controller: _binhLuanCtrl,
                    hint: _dangTraLoiId != null
                        ? 'Nhập câu trả lời...'
                        : 'Viết bình luận...',
                    dangGui: _dangGuiBinhLuan,
                    onSend: _guiBinhLuan,
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LichSuYeuCauCard(
              idTepAnh: _idTepAnh,
              danhSach: _lichSu,
              dangTai: _dangTaiPhuTro,
              laAnhDaChinhSua: laAnhDaChinhSua,
              fmt: _fmt,
            ),
          ),
        ],
      ),
    );
  }

  String _tenTrangThai(String? v) {
    switch (v) {
      case 'da_yeu_cau':
        return 'Đã yêu cầu';
      case 'da_chot':
        return 'Đã chốt';
      case 'chua_yeu_cau':
      case null:
        return 'Chưa yêu cầu chỉnh sửa';
      default:
        return v;
    }
  }
}

// ---------------------------------------------------------------------------
// Widget phụ
// ---------------------------------------------------------------------------
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(title.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                if (trailing != null)
                  Text(trailing!,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline)),
            ),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _YeuCauCard extends StatefulWidget {
  const _YeuCauCard({
    required this.y,
    required this.fmt,
    this.onSua,
    this.onXoa,
    this.dangXoa = false,
  });
  final Map<String, dynamic> y;
  final String Function(dynamic) fmt;

  /// null = không được sửa (thiếu quyền hoặc đã chốt).
  final Future<void> Function(String id, String noiDung)? onSua;
  final VoidCallback? onXoa;
  final bool dangXoa;

  @override
  State<_YeuCauCard> createState() => _YeuCauCardState();
}

class _YeuCauCardState extends State<_YeuCauCard> {
  bool _dangSua = false;
  bool _dangLuu = false;
  late final TextEditingController _ctrl = TextEditingController(
      text: widget.y['noi_dung_yeu_cau']?.toString() ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (_dangLuu || widget.onSua == null) return;
    setState(() => _dangLuu = true);
    try {
      await widget.onSua!(
          widget.y['id_yeu_cau_chinh_sua'].toString(), _ctrl.text.trim());
      if (mounted) setState(() => _dangSua = false);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.y;
    final tt = y['trang_thai_yeu_cau']?.toString();
    final ten = y['nguoi_yeu_cau_ho_ten']?.toString() ??
        (y['tai_khoan_khach_hang_id'] != null
            ? 'Khách hàng'
            : 'Nhân viên studio');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(ten,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
                Text(tt ?? '—',
                    style: TextStyle(fontSize: 10, color: AppColors.primary)),
                if (widget.onSua != null && !_dangSua)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    tooltip: 'Sửa nội dung yêu cầu',
                    onPressed: () => setState(() => _dangSua = true),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (widget.onXoa != null && !_dangSua)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    tooltip: 'Xóa yêu cầu chỉnh sửa này',
                    onPressed: widget.dangXoa ? null : widget.onXoa,
                    icon: widget.dangXoa
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (_dangSua) ...[
              TextField(
                controller: _ctrl,
                enabled: !_dangLuu,
                maxLength: 2000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _dangLuu
                          ? null
                          : () => setState(() {
                                _dangSua = false;
                                _ctrl.text =
                                    y['noi_dung_yeu_cau']?.toString() ?? '';
                              }),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: _dangLuu ? null : _luu,
                      child: Text(_dangLuu ? 'Đang lưu...' : 'Lưu')),
                ],
              ),
            ] else if ((y['noi_dung_yeu_cau']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(y['noi_dung_yeu_cau'].toString(),
                    style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 6),
            _Moc('Đã yêu cầu', widget.fmt(y['created_at'])),
            if (y['chot_luc'] != null)
              _Moc('Đã chốt yêu cầu', widget.fmt(y['chot_luc'])),
            if (tt == 'hoan_thanh')
              _Moc('Hoàn thành', widget.fmt(y['chot_luc'] ?? y['updated_at'])),
          ],
        ),
      ),
    );
  }
}

class _Moc extends StatelessWidget {
  const _Moc(this.label, this.time);
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('• $label — $time',
            style: TextStyle(
                fontSize: 10, color: Theme.of(context).colorScheme.outline)),
      );
}

class _BinhLuanCard extends StatelessWidget {
  const _BinhLuanCard({
    required this.bl,
    required this.fmt,
    required this.onReply,
    this.isReply = false,
  });
  final Map<String, dynamic> bl;
  final String Function(dynamic) fmt;
  final VoidCallback onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final daGiaiQuyet = bl['da_giai_quyet'] == true;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 20 : 0, bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: daGiaiQuyet
                  ? Colors.green.shade200
                  : Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${bl['nguoi_binh_luan_ho_ten'] ?? 'Ẩn danh'} · ${fmt(bl['created_at'])}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                if (daGiaiQuyet)
                  const Text('Đã giải quyết',
                      style: TextStyle(fontSize: 9, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 4),
            Text(bl['noi_dung']?.toString() ?? '',
                style: const TextStyle(fontSize: 12)),
            InkWell(
              onTap: onReply,
              child: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Trả lời', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XemThem extends StatelessWidget {
  const _XemThem(
      {required this.dangMoRong, required this.soAn, required this.onToggle});
  final bool dangMoRong;
  final int soAn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (soAn <= 0 && !dangMoRong) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: onToggle,
        child: Text(dangMoRong ? 'Thu gọn' : 'Xem thêm $soAn'),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.hint,
    required this.dangGui,
    required this.onSend,
  });
  final TextEditingController controller;
  final String hint;
  final bool dangGui;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !dangGui,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: dangGui ? null : onSend,
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: dangGui
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
          ),
        ],
      );
}
