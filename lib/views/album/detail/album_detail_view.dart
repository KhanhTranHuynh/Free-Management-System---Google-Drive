import 'package:flutter/material.dart';

import '../../../apis/api_request_manager.dart';
import '../../../apis/services/album_api.dart';
import '../../../apis/services/binh_luan_anh_api.dart';
import '../../../apis/services/tep_anh_api.dart';
import '../../../apis/services/yeu_cau_chinh_sua_api.dart';
import 'album_detail_constants.dart';
import 'album_detail_controller.dart';
import 'album_header.dart';
import 'anh_detail_sheet.dart';
import 'bottom_action_bar.dart';
import 'photo_filter_bar.dart';
import 'photo_grid.dart';

/// Tương ứng DetailAlbum.jsx: chỉ ghép controller + widget con.
class AlbumDetailView extends StatefulWidget {
  const AlbumDetailView({
    super.key,
    required this.idAlbum,
    // TODO: lấy từ hệ thống phân quyền thật (useCoQuyen bên React).
    this.quyen = const AlbumQuyen(),
  });

  final String idAlbum;
  final AlbumQuyen quyen;

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  late final AlbumDetailController _c;
  late final TepAnhApi _tepAnhApi;
  late final YeuCauChinhSuaApi _ycsApi;
  late final BinhLuanAnhApi _blApi;

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _requestCtrl = TextEditingController();

  String? _idAnhDangXem;

  AlbumQuyen get _q => widget.quyen;

  @override
  void initState() {
    super.initState();
    final rm = ApiRequestManager.instance;
    _tepAnhApi = TepAnhApi(rm);
    _ycsApi = YeuCauChinhSuaApi(rm);
    _blApi = BinhLuanAnhApi(rm);

    _c = AlbumDetailController(
      idAlbum: widget.idAlbum,
      albumApi: AlbumApi(rm),
      tepAnhApi: _tepAnhApi,
      ycsApi: _ycsApi,
      onMessage: _thongBao,
    )..khoiTao();

    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    _requestCtrl.dispose();
    _c.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _c.taiThem();
    }
  }

  void _thongBao(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _xacNhan({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Đóng')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _chotTatCa() async {
    final ok = await _xacNhan(
      title: 'Chốt tất cả yêu cầu chỉnh sửa',
      message: 'Chốt yêu cầu chỉnh sửa cho ${_c.tongSo} ảnh đã yêu cầu?',
      confirmLabel: 'Chốt tất cả',
    );
    if (ok) await _c.chotTatCaAlbum(_q);
  }

  Future<void> _xoaCungTatCa() async {
    final ok = await _xacNhan(
      title: 'Hủy yêu cầu chưa chốt',
      message:
          'Xóa vĩnh viễn tất cả yêu cầu chỉnh sửa chưa chốt của album này?',
      confirmLabel: 'Xác nhận',
    );
    if (ok) await _c.xoaCungTatCaAlbum(_q);
  }

  /// Ô lọc hiện theo tab — khớp các cờ showXxxFilter của PhotoFilterBar.jsx.
  List<FilterSpec> _buildFilters() {
    final t = _c.activeTab;
    final laYeuCau = t == AlbumTab.yeuCau || t == AlbumTab.chotYeuCau;
    return [
      if (t == AlbumTab.anh)
        FilterSpec(
          label: 'Ảnh đã chọn',
          value: _c.daChonFilter,
          options: const [
            {'value': 'da_chon', 'label': 'Đã chọn'},
            {'value': 'chua_chon', 'label': 'Chưa chọn'},
          ],
          onChanged: _c.doiDaChonFilter,
        ),
      FilterSpec(
        label: 'Ver ảnh',
        value: _c.verAnhFilter,
        options: _c.verAnhOptions,
        onChanged: (v) => _c.doiFilter('ver_anh', v),
      ),
      if (t == AlbumTab.anh)
        FilterSpec(
          label: 'Trạng thái',
          value: _c.trangThaiAnhFilter,
          options: _c.trangThaiOptions.isNotEmpty
              ? _c.trangThaiOptions
              : const [
                  {'value': 'chua_yeu_cau', 'label': 'Chưa yêu cầu'},
                  {'value': 'da_yeu_cau', 'label': 'Đã yêu cầu'},
                  {'value': 'da_chot', 'label': 'Đã chốt'},
                ],
          onChanged: _c.doiTrangThaiAnhFilter,
        ),
      if (laYeuCau || t == AlbumTab.daSua)
        FilterSpec(
          label: 'Lần yêu cầu',
          value: _c.lanYeuCauFilter,
          options: _c.lanYeuCauOptions,
          onChanged: (v) => _c.doiFilter('lan_yeu_cau', v),
        ),
      if (t == AlbumTab.chotYeuCau || t == AlbumTab.daSua)
        FilterSpec(
          label: 'Lần chốt',
          value: _c.lanChotFilter,
          options: _c.lanChotOptions,
          onChanged: (v) => _c.doiFilter('lan_chot', v),
        ),
      if (laYeuCau)
        FilterSpec(
          label: 'Tiến độ',
          value: _c.tienDoFilter,
          options: _c.tienDoOptions,
          onChanged: (v) => _c.doiFilter('tien_do', v),
        ),
    ];
  }

  void _moChiTietAnh(Map<String, dynamic> anh) {
    setState(() => _idAnhDangXem = anh['id_tep_anh'].toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (context, sc) => AnhDetailSheet(
          idAlbum: widget.idAlbum,
          anhBanDau: anh,
          tepAnhApi: _tepAnhApi,
          ycsApi: _ycsApi,
          blApi: _blApi,
          scrollController: sc,
          onThayDoi: _c.lamMoi,
          quyen: _q,
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _idAnhDangXem = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _TopBar(
              tenAlbum: _c.album?['ten_album']?.toString(),
              dangTai: _c.isLoadingHeader && _c.album == null,
            ),
          ),
          Expanded(child: _buildNoiDung()),
        ],
      ),
    );
  }

  Widget _buildNoiDung() {
    if (_c.errorHeader != null && _c.album == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_c.errorHeader!),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _c.taiHeader, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final tab = _c.activeTab;
    final laTabYeuCau = tab == AlbumTab.yeuCau;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _c.lamMoi,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: AlbumHeader(
                  album: _c.album,
                  isLoading: _c.isLoadingHeader,
                  thongKe: _c.thongKe,
                  activeTab: tab,
                  onChangeTab: (t) {
                    _searchCtrl.clear();
                    _c.doiTab(t);
                  },
                  albumDaKhoa: _c.albumDaKhoa,
                  // TODO: nối EditAlbum / UploadDrive khi có view.
                  onSuaAlbum: null,
                  onTaiAnhLenDrive: null,
                ),
              ),
              if (laTabYeuCau) const SliverToBoxAdapter(child: _InfoBanner()),
              SliverToBoxAdapter(
                child: PhotoFilterBar(
                  activeTab: tab,
                  searchController: _searchCtrl,
                  onSearchChanged: _c.timKiemDebounce,
                  filters: _buildFilters(),
                  onChotTatCaAlbum:
                      laTabYeuCau && _q.chotTatCa ? _chotTatCa : null,
                  dangChotTatCaAlbum: _c.dangChotTatCa,
                  onXoaCungTatCaAlbum:
                      laTabYeuCau && _q.xoaCungTatCa ? _xoaCungTatCa : null,
                  dangXoaCungTatCaAlbum: _c.dangXoaCungTatCa,
                  // TODO: onTaiAnhVe / onDoiChieuAnh / onUploadToanBo
                  // cần API + view tương ứng (xem danh sách thiếu).
                ),
              ),
              PhotoGridSliver(
                anhList: _c.anh,
                isLoading: _c.isLoading,
                isLoadingMore: _c.isLoadingMore,
                error: _c.errorAnh,
                emptyMessage: AlbumTab.emptyMessages[tab]!,
                idAnhDangXem: _idAnhDangXem,
                anBadgeTrangThai: _c.anBadgeTrangThai,
                onSelectPhoto: _moChiTietAnh,
                onToggleChonAnh:
                    _q.chonAnh ? (a) => _c.toggleChonAnh(a, _q) : null,
                dangDoiChonIds: _c.dangDoiChon,
                onXoaYeuCauAnh:
                    _q.huyYeuCau ? (a) => _c.xoaYeuCauMotAnh(a, _q) : null,
                dangXoaYeuCauIds: _c.dangXoaYeuCauMotAnh,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
        if (_c.hienBottomBar && _c.soDaChon > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomActionBar(
              count: _c.soDaChon,
              requestController: _requestCtrl,
              onSelectAll:
                  _q.chonAnh ? () => _c.chonBoChonTatCa(true, _q) : null,
              onDeselectAll:
                  _q.chonAnh ? () => _c.chonBoChonTatCa(false, _q) : null,
              dangDoiChonTatCa: _c.dangDoiChonTatCa,
              onAddRequest: _q.taoYeuCau
                  ? () async {
                      final ok =
                          await _c.guiYeuCauHangLoat(_requestCtrl.text, _q);
                      if (ok) _requestCtrl.clear();
                    }
                  : null,
              dangThemYeuCau: _c.dangGuiYeuCau,
              coTheThemYeuCau: _c.idTepAnhDaChon.isNotEmpty,
              // React không truyền onClearRequests -> nút xoá ẩn.
              // Muốn bật: onClearRequests: () => _c.huyYeuCauDaChon(_q),
            ),
          ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vui lòng chốt yêu cầu chỉnh sửa để Editor có thể bắt đầu thực hiện.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tenAlbum, required this.dangTai});
  final String? tenAlbum;
  final bool dangTai;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: cs.surfaceContainerHigh, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chi tiết album',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(dangTai ? 'Đang tải...' : (tenAlbum ?? '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
