import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_api.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../components/app_modal.dart';
import '../../components/calendar_custom.dart';
import '../../components/empty_state.dart';
import '../../configs/app_colors.dart';
import '../../stores/auth_store.dart';

/// Tên cũ, giữ để chỗ nào còn dùng `LichPhanCongAlbumView` vẫn chạy.
typedef LichPhanCongAlbumView = LichPhanCongListView;

/// Tương ứng lich-phan-cong.jsx: lịch phân công (lọc nhiều nhân viên) +
/// modal chi tiết (huỷ phân công / đặt làm người báo cáo).
class LichPhanCongListView extends StatefulWidget {
  const LichPhanCongListView({
    super.key,
    this.idAlbum,
    this.nhanVienOptions,
    this.tenAlbum,
  });

  /// null = xem lịch của mọi album.
  final String? idAlbum;
  final List<Map<String, dynamic>>? nhanVienOptions;
  final String? tenAlbum;

  @override
  State<LichPhanCongListView> createState() => _LichPhanCongListViewState();
}

class _LichPhanCongListViewState extends State<LichPhanCongListView> {
  final _api = AlbumApi(ApiRequestManager.instance);
  final _nhanVienApi = NhanVienApi(ApiRequestManager.instance);

  List<Map<String, dynamic>> _nhanVien = [];
  List<Map<String, dynamic>> _danhSachTho = [];
  final Set<String> _locIds = {};

  ({DateTime tu, DateTime den})? _khoang;
  bool _dangTai = false;
  String? _loi;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.nhanVienOptions != null && widget.nhanVienOptions!.isNotEmpty) {
      _nhanVien = widget.nhanVienOptions!;
    } else {
      unawaited(_taiNhanVien());
    }
  }

  // ---------------------------------------------------------------------
  // Dữ liệu
  // ---------------------------------------------------------------------

  /// Chuẩn hoá response nhân viên: List hoặc Map có du_lieu/items/list/data.
  List<Map<String, dynamic>> _chuanHoaMang(dynamic raw) {
    List? l;
    if (raw is List) {
      l = raw;
    } else if (raw is Map) {
      for (final k in ['du_lieu', 'items', 'list', 'data']) {
        if (raw[k] is List) {
          l = raw[k] as List;
          break;
        }
      }
    }
    return [
      for (final e in l ?? const [])
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  Future<void> _taiNhanVien() async {
    try {
      final body = await _nhanVienApi.layDanhSach(trang: 1, soLuong: 100);
      if (!mounted) return;
      setState(() => _nhanVien = _chuanHoaMang(body));
    } catch (e) {
      debugPrint('[PhanCong] LOI tai nhan vien: $e');
    }
  }

  String _isoNgay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _taiLich() async {
    final k = _khoang;
    if (k == null) return;
    final id = ++_requestId;
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await _api.phanCongLich(
        tuNgay: _isoNgay(k.tu),
        denNgay: _isoNgay(k.den),
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _danhSachTho = ds;
        _dangTai = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        // message rỗng = request bị huỷ do có request mới hơn -> im lặng.
        _loi = e.message.isEmpty ? null : e.message;
        _dangTai = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loi = 'Không tải được lịch phân công. Vui lòng thử lại.';
        _dangTai = false;
      });
    }
  }

  void _onDatesSet(DateTime tu, DateTime den) {
    final cu = _khoang;
    if (cu != null && cu.tu == tu && cu.den == den) return;
    _khoang = (tu: tu, den: den);
    unawaited(_taiLich());
  }

  // ---------------------------------------------------------------------
  // Nhân viên
  // ---------------------------------------------------------------------
  List<({String value, String label})> get _nhanVienSelect => [
        for (final nv in _nhanVien)
          (
            value: (nv['id_tai_khoan_nhan_vien'] ?? nv['id'] ?? '').toString(),
            label: (nv['ho_ten'] ?? nv['so_dien_thoai'] ?? '').toString(),
          ),
      ].where((o) => o.value.isNotEmpty).toList();

  String _nhanVienLabel(dynamic id) {
    final s = id?.toString() ?? '';
    for (final o in _nhanVienSelect) {
      if (o.value == s) return o.label.isEmpty ? s : o.label;
    }
    return s;
  }

  List<CalendarEvent> get _events {
    final ds = widget.idAlbum == null
        ? _danhSachTho
        : _danhSachTho
            .where((e) => e['album_id']?.toString() == widget.idAlbum)
            .toList();

    return [
      for (final item in ds)
        if (_locIds.isEmpty ||
            _locIds.contains(item['tai_khoan_nhan_vien_id']?.toString()))
          if (DateTime.tryParse(item['thoi_gian_bat_dau']?.toString() ?? '') !=
              null)
            CalendarEvent(
              id: item['id_album_phu_trach'].toString(),
              title:
                  '${(item['ten_album'] ?? '').toString().isNotEmpty ? '[${item['ten_album']}] ' : ''}${_nhanVienLabel(item['tai_khoan_nhan_vien_id'])}',
              start: DateTime.parse(item['thoi_gian_bat_dau'].toString())
                  .toLocal(),
              end: DateTime.tryParse(
                      item['thoi_gian_ket_thuc']?.toString() ?? '')
                  ?.toLocal(),
              variant: item['la_nguoi_bao_cao'] == true
                  ? CalendarVariant.warning
                  : CalendarVariant.primary,
              data: item,
            ),
    ];
  }

  // ---------------------------------------------------------------------
  // Lọc nhân viên (popup)
  // ---------------------------------------------------------------------
  Future<void> _moLocNhanVien() async {
    final options = _nhanVienSelect;
    final tam = ValueNotifier<Set<String>>({..._locIds});

    final apDung = await showAppModal<bool>(
      context,
      title: 'Lọc nhân viên',
      subTitle: 'Không chọn ai = hiển thị tất cả',
      type: AppModalType.bottomSheet,
      closeOnBackdropClick: true,
      builder: (_) => _LocNhanVienForm(options: options, tam: tam),
      footerBuilder: (ctx) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                tam.value = {};
                Navigator.of(ctx).pop(true);
              },
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Bỏ lọc'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Áp dụng',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    if (apDung != true || !mounted) return;
    setState(() {
      _locIds
        ..clear()
        ..addAll(tam.value);
    });
  }

  // ---------------------------------------------------------------------
  // Modal chi tiết phân công
  // ---------------------------------------------------------------------
  void _moChiTiet(CalendarEvent ev) {
    final item = ev.data;
    if (item == null) return;

    final auth = context.read<AuthStore>();
    final coQuyenXoa = auth.coQuyen('LICH_PHAN_CONG', 'xoa');
    final coQuyenSua = auth.coQuyen('LICH_PHAN_CONG', 'sua');

    final dangXuLy = ValueNotifier<bool>(false);

    Future<void> chay(
      BuildContext ctx,
      Future<dynamic> Function() hanhDong,
      String thanhCong,
      String thatBai,
    ) async {
      dangXuLy.value = true;
      try {
        await hanhDong();
        if (!mounted) return;
        if (ctx.mounted) Navigator.of(ctx).pop();
        _thongBao(thanhCong);
        unawaited(_taiLich());
      } on ApiException catch (e) {
        _thongBao(e.message.isNotEmpty ? e.message : thatBai);
      } catch (_) {
        _thongBao(thatBai);
      } finally {
        dangXuLy.value = false;
      }
    }

    final laBaoCao = item['la_nguoi_bao_cao'] == true;
    final idAlbum = item['album_id'].toString();
    final idPhuTrach = item['id_album_phu_trach'].toString();

    showAppModal<void>(
      context,
      title: 'Chi tiết phân công',
      type: AppModalType.bottomSheet,
      closeOnBackdropClick: true,
      builder: (_) => _ChiTietPhanCongBody(
        item: item,
        tenNhanVien: _nhanVienLabel(item['tai_khoan_nhan_vien_id']),
      ),
      footerBuilder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: dangXuLy,
        builder: (_, busy, __) {
          final error = Theme.of(ctx).colorScheme.error;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!laBaoCao && coQuyenSua) ...[
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => chay(
                            ctx,
                            () => _api.doiNguoiBaoCao(
                              idAlbum: idAlbum,
                              idAlbumPhuTrach: idPhuTrach,
                            ),
                            'Đã đặt làm người báo cáo',
                            'Đổi người báo cáo thất bại',
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('Đặt làm người báo cáo',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                  if (coQuyenXoa) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => chay(
                                  ctx,
                                  () => _api.huyPhanCong(
                                    idAlbum: idAlbum,
                                    idAlbumPhuTrach: idPhuTrach,
                                  ),
                                  'Đã huỷ phân công',
                                  'Huỷ phân công thất bại',
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: error,
                          side: BorderSide(color: error),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Huỷ phân công'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    ).whenComplete(dangXuLy.dispose);
  }

  void _thongBao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dangLoc = _locIds.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _taiLich,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Lịch phân công${widget.tenAlbum != null && widget.tenAlbum!.isNotEmpty ? ' - ${widget.tenAlbum}' : ''}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          // ----- Bộ lọc nhân viên + chú thích -----
          Row(
            children: [
              Badge(
                isLabelVisible: dangLoc,
                label: Text('${_locIds.length}'),
                backgroundColor: AppColors.primary,
                child: OutlinedButton.icon(
                  onPressed: _moLocNhanVien,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor:
                        dangLoc ? AppColors.primary.withOpacity(0.12) : null,
                    foregroundColor: dangLoc ? AppColors.primary : null,
                  ),
                  icon: const Icon(Icons.filter_list_rounded, size: 18),
                  label: const Text('Nhân viên'),
                ),
              ),
              const Spacer(),
              _chuThich(AppColors.primary, 'Phụ trách'),
              const SizedBox(width: 12),
              _chuThich(Colors.amber.shade700, 'Người báo cáo'),
            ],
          ),
          if (dangLoc) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _locIds)
                  _PillNhanVien(
                    text: _nhanVienLabel(id),
                    onClear: () => setState(() => _locIds.remove(id)),
                  ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Chưa chọn ai: đang hiển thị tất cả nhân viên.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 12),

          // ----- Thanh báo lỗi (lịch vẫn giữ nguyên bên dưới) -----
          if (_loi != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_loi!,
                        style: TextStyle(fontSize: 13, color: cs.error)),
                  ),
                  TextButton(onPressed: _taiLich, child: const Text('Thử lại')),
                ],
              ),
            ),

          // ----- Lịch -----
          CalendarCustom(
            events: _events,
            loading: _dangTai,
            maxEventsPerDay: 2,
            onDatesSet: _onDatesSet,
            onEventTap: _moChiTiet,
          ),
        ],
      ),
    );
  }

  Widget _chuThich(Color mau, String nhan) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: mau, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(nhan,
              style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

// ============================================================
// Pill nhân viên đang lọc
// ============================================================
class _PillNhanVien extends StatelessWidget {
  const _PillNhanVien({required this.text, required this.onClear});
  final String text;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(2, 6, 10, 6),
              child:
                  Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Thân popup lọc nhân viên: danh sách checkbox + chọn tất cả
// ============================================================
class _LocNhanVienForm extends StatelessWidget {
  const _LocNhanVienForm({required this.options, required this.tam});

  final List<({String value, String label})> options;
  final ValueNotifier<Set<String>> tam;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const EmptyState(text: 'Chưa có nhân viên nào');
    }
    return ListenableBuilder(
      listenable: tam,
      builder: (context, _) {
        final daChonHet = options.every((o) => tam.value.contains(o.value));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => tam.value =
                    daChonHet ? {} : {for (final o in options) o.value},
                child: Text(daChonHet ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      value: tam.value.contains(o.value),
                      title: Text(o.label.isEmpty ? o.value : o.label),
                      onChanged: (v) {
                        final moi = {...tam.value};
                        v == true ? moi.add(o.value) : moi.remove(o.value);
                        tam.value = moi;
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// Thân modal chi tiết 1 phân công
// ============================================================
class _ChiTietPhanCongBody extends StatelessWidget {
  const _ChiTietPhanCongBody({required this.item, required this.tenNhanVien});

  final Map<String, dynamic> item;
  final String tenNhanVien;

  String _fmt(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (d == null) return 'Chưa đặt';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final laBaoCao = item['la_nguoi_bao_cao'] == true;
    final mau = laBaoCao
        ? (dark ? Colors.amber.shade300 : Colors.amber.shade800)
        : AppColors.primary;
    final chuCai =
        (tenNhanVien.isEmpty ? '?' : tenNhanVien.trim()[0]).toUpperCase();
    final vaiTro = (item['vai_tro_phu_trach']?.toString() ?? '').trim();
    final tenAlbum = (item['ten_album']?.toString() ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mau.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Text(chuCai,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: mau)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(tenNhanVien,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      if (laBaoCao)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: mau.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 13, color: mau),
                              const SizedBox(width: 3),
                              Text('Người báo cáo chính',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: mau)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(vaiTro.isEmpty ? 'Chưa có vai trò cụ thể' : vaiTro,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        if (tenAlbum.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Text('Album',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tenAlbum,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cs.onSurface)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _oThoiGian(context, Icons.play_arrow_rounded, 'BẮT ĐẦU',
                    _fmt(item['thoi_gian_bat_dau']))),
            const SizedBox(width: 12),
            Expanded(
                child: _oThoiGian(context, Icons.stop_rounded, 'KẾT THÚC',
                    _fmt(item['thoi_gian_ket_thuc']))),
          ],
        ),
      ],
    );
  }

  Widget _oThoiGian(
      BuildContext context, IconData icon, String nhan, String giaTri) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(nhan,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(giaTri,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}
