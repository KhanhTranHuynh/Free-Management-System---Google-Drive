import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../apis/api_request_manager.dart';
import '../../../apis/services/album_api.dart';
import '../../../apis/services/album_detail_api.dart';
import '../../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../../apis/services/tep_anh_api.dart';
import '../../../apis/services/trang_thai_album_api.dart';
import '../../../apis/services/yeu_cau_chinh_sua_api.dart';
import '../../../stores/auth_store.dart';
import '../album_edit_sheet.dart';
import 'album_detail_constants.dart';
import 'album_detail_controller.dart';
import 'album_header.dart';
import 'anh_detail_sheet.dart';
import 'bottom_action_bar.dart';
import 'doi_chieu_xuat_anh_sheet.dart';
import 'photo_filter_bar.dart';
import 'photo_grid.dart';
import '../../../utils/tai_anh_util.dart';
import 'upload_anh_da_sua_hang_loat_sheet.dart';

/// Tương ứng DetailAlbum.jsx: chỉ ghép controller + widget con.
/// Quyền lấy từ AuthStore.coQuyen (qua AlbumQuyen.tuAuth).
class AlbumDetailView extends StatefulWidget {
  const AlbumDetailView({super.key, required this.idAlbum});

  final String idAlbum;

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  late final AlbumDetailController _c;
  late final TepAnhApi _tepAnhApi;
  late final YeuCauChinhSuaApi _ycsApi;
  late final AlbumDetailApi _extraApi;
  late final TaiKhoanKhachHangApi _khachHangApi;

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _requestCtrl = TextEditingController();

  String? _idAnhDangXem;

  /// Đọc quyền mới nhất (dùng `read` vì gọi trong handler).
  AlbumQuyen get _q => AlbumQuyen.tuAuth(context.read<AuthStore>());

  @override
  void initState() {
    super.initState();
    final rm = ApiRequestManager.instance;
    _tepAnhApi = TepAnhApi(rm);
    _ycsApi = YeuCauChinhSuaApi(rm);
    _extraApi = AlbumDetailApi(rm);
    _khachHangApi = TaiKhoanKhachHangApi(rm);

    _c = AlbumDetailController(
      idAlbum: widget.idAlbum,
      albumApi: AlbumApi(rm),
      tepAnhApi: _tepAnhApi,
      ycsApi: _ycsApi,
      trangThaiApi: TrangThaiAlbumApi(rm),
      extraApi: _extraApi,
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

  /// handleMoSua + EditAlbumModal (onUpdated -> invalidate header).
  Future<void> _moSua() async {
    final album = _c.album;
    if (album == null || !_q.suaAlbum) return;
    try {
      final body = await _khachHangApi.layDanhSach(trang: 1, soLuong: 100);
      final opts =
          List<Map<String, dynamic>>.from(body['du_lieu'] as List? ?? []);
      if (!mounted) return;
      final daSua = await showEditAlbumModal(
        context,
        album: album,
        khachHangOptions: opts,
      );
      if (daSua != null && daSua != false) await _c.taiHeader();
    } catch (_) {
      _thongBao('Không mở được form chỉnh sửa album');
    }
  }

  void _moDoiChieu() {
    hienDoiChieuXuatAnh(context, api: _extraApi, idAlbum: widget.idAlbum);
  }

  void _moUploadToanBo() {
    final album = _c.album;
    if (album == null) return;
    hienUploadAnhDaSuaHangLoat(
      context,
      api: _extraApi,
      idAlbum: widget.idAlbum,
      lanChotOptions: _c.lanChotOptions,
      onUploaded: _c.lamMoi,
    );
  }

  /// Ô lọc hiện theo tab — khớp các cờ showXxxFilter trong DetailAlbum.jsx.
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
          options: _c.trangThaiOptions,
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
    ];
  }

  void _moChiTietAnh(Map<String, dynamic> anh) {
    final quyen = _q; // chụp quyền tại thời điểm mở sheet
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
          extraApi: _extraApi,
          scrollController: sc,
          onThayDoi: _c.lamMoi,
          quyen: quyen,
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _idAnhDangXem = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch để build lại khi quyền trong AuthStore thay đổi.
    final auth = context.watch<AuthStore>();

    if (!auth.coQuyen('ALBUM', 'xem')) {
      return const Center(child: Text('Không có quyền xem'));
    }

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
          Expanded(child: _buildNoiDung(AlbumQuyen.tuAuth(auth))),
        ],
      ),
    );
  }

  Widget _buildNoiDung(AlbumQuyen q) {
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
    final laTabChot = tab == AlbumTab.chotYeuCau;

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
                  trangThaiHienTai: _c.trangThaiHienTai,
                  albumDaKhoa: _c.albumDaKhoa,
                  hienMatKhau: q.laNhanVien && q.xemMatKhau,
                  layMatKhau: () => _extraApi.layMatKhau(widget.idAlbum),
                  onSuaAlbum: q.suaAlbum ? _moSua : null,
                  // TODO: cần UploadDriveModal.jsx để port.
                  onTaiAnhLenDrive: null,
                ),
              ),
              if (laTabYeuCau) const SliverToBoxAdapter(child: _InfoBanner()),
              SliverToBoxAdapter(
                child: PhotoFilterBar(
                  activeTab: tab,
                  tongSo: _c.tongSo,
                  searchController: _searchCtrl,
                  onSearchChanged: _c.timKiemDebounce,
                  filters: _buildFilters(),
                  onChotTatCaAlbum:
                      laTabYeuCau && q.chotTatCa ? _chotTatCa : null,
                  dangChotTatCaAlbum: _c.dangChotTatCa,
                  onXoaCungTatCaAlbum:
                      laTabYeuCau && q.xoaCungTatCa ? _xoaCungTatCa : null,
                  dangXoaCungTatCaAlbum: _c.dangXoaCungTatCa,
                  // React: tab != yeu_cau, không cần quyền.
                  onTaiAnhVe: laTabYeuCau ? null : _c.taiAnhVe,
                  dangTaiAnhVe: _c.dangTaiAnhVe,
                  soLuongTaiTatCa:
                      (_c.thongKe['tong_so_hinh'] as num?)?.toInt(),
                  soLuongTaiBoLoc: _c.tongSo,
                  // React: chỉ ở tab "Đã chốt".
                  onDoiChieuAnh: laTabChot ? _moDoiChieu : null,
                  onUploadToanBo: laTabChot ? _moUploadToanBo : null,
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