import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../apis/services/album_detail_api.dart';
import '../../../../apis/services/tep_anh_api.dart';
import '../../../../apis/services/yeu_cau_chinh_sua_api.dart';
import '../../../../configs/app_colors.dart';
import 'album_detail_constants.dart';
import 'anh_lien_quan_sheet.dart';
import 'lich_su_yeu_cau_card.dart';
import 'so_sanh_phien_ban.dart';
import '../../../utils/tai_anh_util.dart';
import 'upload_ket_qua_dialog.dart';

/// Tương ứng DetailPanel.jsx (phiên bản mobile, bottom sheet).
/// Quyền truyền từ view cha (dựng từ AuthStore.coQuyen), không hard-code.
class AnhDetailSheet extends StatefulWidget {
  const AnhDetailSheet({
    super.key,
    required this.idAlbum,
    required this.anhBanDau,
    required this.tepAnhApi,
    required this.ycsApi,
    required this.extraApi,
    required this.scrollController,
    required this.onThayDoi,
    required this.quyen,
  });

  final String idAlbum;
  final Map<String, dynamic> anhBanDau;
  final TepAnhApi tepAnhApi;
  final YeuCauChinhSuaApi ycsApi;
  final AlbumDetailApi extraApi;
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
  bool _dangTaiAnh = false;
  String? _dangTraLoiId;
  String? _dangDoiGiaiQuyetId;
  String? _dangXoaBinhLuanId;
  bool _moRongYeuCau = false;
  bool _moRongBinhLuan = false;

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

  // gộp dữ liệu list + chi tiết (chi tiết không được ghi đè bằng null)
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

  void _msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  // ---------------- Tải ảnh ----------------
  Future<void> _taiAnh() async {
    if (_dangTaiAnh) return;
    setState(() => _dangTaiAnh = true);
    try {
      final ok = await TaiAnh.taiMotAnh(_anh);
      if (!ok) _msg('Không có link tải ảnh');
    } catch (_) {
      _msg('Tải ảnh thất bại');
    }
    if (mounted) setState(() => _dangTaiAnh = false);
  }

  // ---------------- Yêu cầu ----------------
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

  /// taoYeuCauChinhSuaAnh bên React: chưa chọn thì chọn ảnh trước (cần
  /// quyền chọn), rồi mới tạo yêu cầu.
  Future<void> _guiYeuCau() async {
    final noiDung = _yeuCauCtrl.text.trim();
    if (noiDung.isEmpty || _dangGuiYeuCau) return;
    setState(() => _dangGuiYeuCau = true);
    try {
      if (_anh['duoc_khach_chon'] != true) {
        if (!widget.quyen.chonAnh) {
          _msg('Bạn không có quyền chọn ảnh để gửi yêu cầu chỉnh sửa.');
          return;
        }
        await widget.tepAnhApi.chonTepAnh(
            idAlbum: widget.idAlbum, idTepAnh: [_idTepAnh], chon: true);
      }
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

  // ---------------- Bình luận ----------------
  Future<void> _guiBinhLuan() async {
    final noiDung = _binhLuanCtrl.text.trim();
    if (noiDung.isEmpty || _dangGuiBinhLuan) return;
    setState(() => _dangGuiBinhLuan = true);
    try {
      await widget.extraApi.taoBinhLuan(
        idTepAnh: _idTepAnh,
        noiDung: noiDung,
        binhLuanChaId: _dangTraLoiId,
      );
      _binhLuanCtrl.clear();
      _msg('Đã gửi bình luận');
      if (mounted) setState(() => _dangTraLoiId = null);
      await _taiChiTiet();
    } catch (_) {
      _msg('Gửi bình luận thất bại, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _dangGuiBinhLuan = false);
    }
  }

  Future<void> _doiGiaiQuyet(String id, bool moi) async {
    if (_dangDoiGiaiQuyetId != null) return;
    setState(() => _dangDoiGiaiQuyetId = id);
    try {
      await widget.extraApi.giaiQuyetBinhLuan(id, moi);
      _msg('Đã cập nhật trạng thái giải quyết');
      await _taiChiTiet();
    } catch (_) {
      _msg('Cập nhật thất bại');
    }
    if (mounted) setState(() => _dangDoiGiaiQuyetId = null);
  }

  Future<void> _xoaBinhLuan(String id) async {
    if (_dangXoaBinhLuanId != null) return;
    setState(() => _dangXoaBinhLuanId = id);
    try {
      await widget.extraApi.xoaBinhLuan(id);
      _msg('Đã xoá bình luận');
      if (_dangTraLoiId == id) _dangTraLoiId = null;
      await _taiChiTiet();
    } catch (_) {
      _msg('Xoá bình luận thất bại');
    }
    if (mounted) setState(() => _dangXoaBinhLuanId = null);
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
    final q = widget.quyen;
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

    final url = urlXemCuaAnh(anh);

    Map<String, dynamic>? layKe(String k) =>
        _keBen?[k] is Map ? Map<String, dynamic>.from(_keBen![k] as Map) : null;
    final verTruoc = layKe('truoc');
    final verSau = layKe('sau');
    final coSoSanh = verTruoc != null || verSau != null;
    final laAnhDaChinhSua = lanSua > 0 || verTruoc != null;
    final yeuCauCoTheUpload = yeuCauCuaAnh
        .where((y) => y['trang_thai_yeu_cau'] != 'hoan_thanh')
        .firstOrNull;

    // React: canUploadKetQua = laNhanVien && anh.duoc_phep_upload_ket_qua
    final coTheUpload = q.laNhanVien &&
        anh['duoc_phep_upload_ket_qua'] == true &&
        yeuCauCoTheUpload != null;

    final tuNoiDungCha = _dangTraLoiId == null
        ? null
        : binhLuan
            .where((b) => b['id_binh_luan_anh']?.toString() == _dangTraLoiId)
            .firstOrNull?['noi_dung']
            ?.toString();

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
              child: GestureDetector(
                onTap: () =>
                    hienXemAnhToanManHinh(context, ds: [anh], batDau: 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _dangTaiAnh ? null : _taiAnh,
                icon: _dangTaiAnh
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 14),
                label: Text(_dangTaiAnh ? 'Đang tải...' : 'Tải ảnh'),
              ),
              if (coTheUpload)
                OutlinedButton.icon(
                  onPressed: () => _upload(yeuCauCoTheUpload),
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
              _Row('Trạng thái hiện tại của ảnh',
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
                      onSua: (q.suaYeuCau && chuaChot) ? _suaYeuCau : null,
                      onXoa: (q.huyYeuCau &&
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
                  else if (q.taoYeuCau)
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
                  ...threadHienThi.map((th) {
                    Widget card(Map<String, dynamic> bl, bool isReply) {
                      final id = bl['id_binh_luan_anh'].toString();
                      return _BinhLuanCard(
                        bl: bl,
                        fmt: _fmt,
                        isReply: isReply,
                        onReply: () => setState(() {
                          _dangTraLoiId = id;
                          _moRongBinhLuan = true;
                        }),
                        // React: canResolve = laNhanVien; canDelete =
                        // laNhanVien || người bình luận cùng loại phiên.
                        onToggleResolve: q.laNhanVien
                            ? () => _doiGiaiQuyet(
                                id, !(bl['da_giai_quyet'] == true))
                            : null,
                        onDelete: q.laNhanVien ? () => _xoaBinhLuan(id) : null,
                        dangXoa: _dangXoaBinhLuanId == id,
                      );
                    }

                    return Column(
                      children: [
                        card(th.root, false),
                        ...th.traLoi.map((r) => card(r, true)),
                      ],
                    );
                  }),
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
                          Expanded(
                              child: Text(
                                  (tuNoiDungCha != null &&
                                          tuNoiDungCha.isNotEmpty)
                                      ? 'Đang trả lời "${tuNoiDungCha.length > 40 ? '${tuNoiDungCha.substring(0, 40)}…' : tuNoiDungCha}"'
                                      : 'Đang trả lời 1 bình luận',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11))),
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
    final cs = Theme.of(context).colorScheme;
    final tt = y['trang_thai_yeu_cau']?.toString();
    final ten = y['nguoi_yeu_cau_ho_ten']?.toString() ??
        (y['tai_khoan_khach_hang_id'] != null
            ? 'Khách hàng'
            : 'Nhân viên studio');
    final nguoiThucHien = y['nguoi_thuc_hien_ho_ten']?.toString();

    // Timeline như DetailPanel.jsx: mới nhất hiển thị trước.
    final moc = <(String, String?)>[
      ('$ten đã yêu cầu', widget.fmt(y['created_at'])),
      if (nguoiThucHien != null && nguoiThucHien.isNotEmpty)
        ('$nguoiThucHien đang thực hiện', null),
      if (y['chot_luc'] != null) ('Đã chốt yêu cầu', widget.fmt(y['chot_luc'])),
      if (tt == 'hoan_thanh')
        ('Hoàn thành', widget.fmt(y['chot_luc'] ?? y['updated_at'])),
    ].reversed.toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(YcsTrangThai.label[tt] ?? tt ?? '—',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.primary)),
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
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(y['noi_dung_yeu_cau'].toString(),
                    style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 4),
            for (final m in moc)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• ${m.$1}${m.$2 != null ? ' — ${m.$2}' : ''}',
                    style: TextStyle(fontSize: 10, color: cs.outline)),
              ),
            if (y['chot_luc'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(y['mien_phi'] == true ? 'Miễn phí' : 'Tính phí',
                    style: TextStyle(fontSize: 10, color: cs.outline)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BinhLuanCard extends StatelessWidget {
  const _BinhLuanCard({
    required this.bl,
    required this.fmt,
    required this.onReply,
    this.onToggleResolve,
    this.onDelete,
    this.dangXoa = false,
    this.isReply = false,
  });
  final Map<String, dynamic> bl;
  final String Function(dynamic) fmt;
  final VoidCallback onReply;
  final VoidCallback? onToggleResolve;
  final VoidCallback? onDelete;
  final bool dangXoa;
  final bool isReply;

  static const _nhanLoai = {
    'nhan_vien': 'Nhân viên',
    'khach_hang': 'Khách hàng',
    'khach_vang_lai': 'Khách vãng lai',
  };

  @override
  Widget build(BuildContext context) {
    final daGiaiQuyet = bl['da_giai_quyet'] == true;
    final ten = bl['nguoi_binh_luan_ho_ten']?.toString() ??
        _nhanLoai[bl['loai_nguoi_binh_luan']] ??
        'Ẩn danh';
    const styleNut = TextStyle(fontSize: 10);
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
                    '$ten · ${fmt(bl['created_at'])}',
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
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 26),
                      padding: const EdgeInsets.symmetric(horizontal: 6)),
                  onPressed: onReply,
                  child: const Text('Trả lời', style: styleNut),
                ),
                if (onToggleResolve != null)
                  TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: Colors.green.shade700),
                    onPressed: onToggleResolve,
                    child: Text(daGiaiQuyet ? 'Bỏ giải quyết' : 'Đánh dấu xong',
                        style: styleNut),
                  ),
                if (onDelete != null)
                  TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: Colors.red.shade600),
                    onPressed: dangXoa ? null : onDelete,
                    child: const Text('Xoá', style: styleNut),
                  ),
              ],
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
