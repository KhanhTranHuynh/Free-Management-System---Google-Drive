import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_api.dart';
import '../../apis/services/trang_thai_album_api.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../stores/auth_store.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật trong dự án (giống
// nhan_vien_list_view.dart).
import '../../configs/app_colors.dart';
import '../../components/o_tim_kiem.dart';
import '../../components/empty_state.dart';
import '../../components/error_retry.dart';
// TODO: chỉnh lại đường dẫn/tên class cho khớp file date picker đã tạo.
import '../../components/app_date_picker.dart';
// TODO: chỉnh lại đường dẫn cho khớp file chứa showAppModal.
import '../../components/app_modal.dart';
import 'album_events.dart';
import 'album_card.dart';
import 'tabs_with_count.dart';
import 'album_add_sheet.dart';
import 'album_edit_sheet.dart';
import 'album_phan_cong_sheet.dart';

/// Danh sách album. Bố cục theo NhanVienListView (Column, không dùng
/// CustomScrollView/sliver nữa để tránh lỗi SliverGeometry):
/// - Header: tiêu đề + phụ đề (tổng số) + nút "Thêm".
/// - Hàng tìm kiếm (OTimKiem) + nút lọc ngày tạo.
/// - Pill tóm tắt lọc ngày (chỉ hiện khi đang lọc).
/// - Tabs trạng thái (có đếm số lượng).
/// - Lưới album (GridView) có kéo-để-làm-mới + infinite scroll.
class AlbumListView extends StatefulWidget {
  const AlbumListView({super.key});

  @override
  State<AlbumListView> createState() => _AlbumListViewState();
}

class _AlbumListViewState extends State<AlbumListView> {
  static const int _soLuongMoiLan = 100;
  static const double _scrollThresholdPx = 300;
  static const Duration _debounceTimKiem = Duration(milliseconds: 400);

  final _api = AlbumApi(ApiRequestManager.instance);
  final _trangThaiApi = TrangThaiAlbumApi(ApiRequestManager.instance);
  final _nhanVienApi = NhanVienApi(ApiRequestManager.instance);
  final _khachHangApi = TaiKhoanKhachHangApi(ApiRequestManager.instance);

  final _scrollController = ScrollController();
  final _timKiemController = TextEditingController();
  Timer? _debounceTimer;
  StreamSubscription<void>? _eventSub;

  // ----- dữ liệu danh sách -----
  List<Map<String, dynamic>> _items = [];
  int _trang = 1;
  int _totalItems = 0;
  bool _isLoading = false; // tải trang đầu (thay toàn bộ data)
  bool _isLoadingMore = false; // tải thêm (nối vào data)
  String? _error;
  int _requestId = 0;

  // ----- filter / search -----
  String _timKiem = '';
  String? _filterTrangThai;
  DateTime? _tuNgay; // lọc từ ngày (null = không giới hạn)
  DateTime? _denNgay; // lọc đến ngày (null = không giới hạn)

  // ----- options -----
  List<Map<String, dynamic>> _trangThaiOptions = [];
  List<Map<String, dynamic>> _nhanVienOptions = [];
  List<Map<String, dynamic>> _khachHangOptions = [];

  // ----- đếm theo trạng thái (badge trên tab) -----
  Map<String, int> _soLuongTheoTrangThai = {};

  // ----- quyền: đọc qua Provider -----
  bool _coQuyen(String module, String hanhDong) =>
      context.read<AuthStore>().coQuyen(module, hanhDong);

  bool get _coQuyenXem => _coQuyen('ALBUM', 'xem');
  bool get _coQuyenThem => _coQuyen('ALBUM', 'them');
  bool get _coQuyenSua => _coQuyen('ALBUM', 'sua');
  bool get _coQuyenXoa => _coQuyen('ALBUM', 'xoa');
  bool get _coQuyenPhanCong => _coQuyen('LICH_PHAN_CONG', 'them');

  int get _tongTatCa =>
      _soLuongTheoTrangThai.values.fold(0, (sum, n) => sum + n);

  List<TabCountOption> get _tabOptions => [
        TabCountOption(gia_tri: null, nhan: 'Tất cả', soLuong: _tongTatCa),
        for (final tt in _trangThaiOptions)
          TabCountOption(
            gia_tri: tt['ma_trang_thai']?.toString(),
            nhan: tt['ten_hien_thi']?.toString() ?? '--',
            soLuong: _soLuongTheoTrangThai[tt['ma_trang_thai']] ?? 0,
          ),
      ];

  bool get _hasMore => _items.length < _totalItems;

  bool get _dangLocNgay => _tuNgay != null || _denNgay != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _eventSub = AlbumEvents.instance.canTaiLai$.listen((_) => _taiLai());
    unawaited(_taiOptions());
    unawaited(_taiLai());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _eventSub?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _timKiemController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Tải dữ liệu
  // ---------------------------------------------------------------------

  Future<void> _taiOptions() async {
    try {
      final ket = await Future.wait([
        _khachHangApi.layDanhSach(trang: 1, soLuong: 100),
        _nhanVienApi.layDanhSach(trang: 1, soLuong: 100, trangThai: true),
        // Không truyền dangHoatDong (không có trong chữ ký API) — lọc
        // "đang hoạt động" ở phía client ngay bên dưới.
        _trangThaiApi.danhSach(trang: 1, soLuong: 100),
      ]);

      if (!mounted) return;

      final dsTrangThai =
          List<Map<String, dynamic>>.from(ket[2]['du_lieu'] as List? ?? [])
              .where((e) => e['dang_hoat_dong'] == true)
              .toList()
            ..sort((a, b) {
              final ta = (a['thu_tu'] as num?)?.toInt() ?? 0;
              final tb = (b['thu_tu'] as num?)?.toInt() ?? 0;
              return ta.compareTo(tb);
            });

      setState(() {
        _khachHangOptions =
            List<Map<String, dynamic>>.from(ket[0]['du_lieu'] as List? ?? []);
        _nhanVienOptions =
            List<Map<String, dynamic>>.from(ket[1]['du_lieu'] as List? ?? []);
        _trangThaiOptions = dsTrangThai;
      });
    } catch (e, st) {
      // Lỗi tải options không chặn danh sách chính.
      debugPrint('[Album] LOI khi tai options: $e\n$st');
    }
  }

  Future<void> _taiLai({bool append = false}) async {
    if (!_coQuyenXem) {
      setState(() {
        _items = [];
        _totalItems = 0;
        _soLuongTheoTrangThai = {};
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final id = ++_requestId;
    final trangCanTai = append ? _trang + 1 : 1;

    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _isLoadingMore = false;
      }
      _error = null;
    });

    try {
      final body = await _api.danhSach(
        trang: trangCanTai,
        soLuong: _soLuongMoiLan,
        timKiem: _timKiem,
        trangThai:
            _filterTrangThai == null ? null : int.tryParse(_filterTrangThai!),
        tuNgayTao: _tuNgay?.toIso8601String(),
        // "Đến ngày" tính hết ngày đó (23:59:59) để không bỏ sót album tạo
        // trong chính ngày được chọn.
        denNgayTao: _denNgay == null
            ? null
            : DateTime(
                    _denNgay!.year, _denNgay!.month, _denNgay!.day, 23, 59, 59)
                .toIso8601String(),
      );

      if (!mounted || id != _requestId) return; // có request mới hơn

      final list =
          List<Map<String, dynamic>>.from(body['du_lieu'] as List? ?? []);
      final phanTrang =
          Map<String, dynamic>.from(body['phan_trang'] as Map? ?? {});
      final soLuongTheoTT = Map<String, dynamic>.from(
          body['so_luong_theo_trang_thai'] as Map? ?? {});

      setState(() {
        _totalItems = (phanTrang['tong_so'] as num?)?.toInt() ?? list.length;
        _soLuongTheoTrangThai =
            soLuongTheoTT.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
        _items = append ? [..._items, ...list] : list;
        _trang = trangCanTai;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      if (e.message.isEmpty) {
        // request bị huỷ do có request mới hơn -> im lặng bỏ qua
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }
      setState(() {
        _error = e.message;
        if (!append) {
          _items = [];
          _totalItems = 0;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        if (!append) {
          _items = [];
          _totalItems = 0;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore || _error != null) return;
    if (!_coQuyenXem) return;

    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _scrollThresholdPx) {
      unawaited(_taiLai(append: true));
    }
  }

  // ---------------------------------------------------------------------
  // Sự kiện người dùng
  // ---------------------------------------------------------------------

  void _onTimKiemChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceTimKiem, () {
      if (!mounted) return;
      setState(() => _timKiem = value.trim());
      unawaited(_taiLai());
    });
  }

  void _onChonTab(String? maTrangThai) {
    if (maTrangThai == _filterTrangThai) return;
    setState(() => _filterTrangThai = maTrangThai);
    unawaited(_taiLai());
  }

  /// Mở modal "Lọc theo ngày tạo" (showAppModal dạng bottom sheet) với 2 ô
  /// DatePickerField (Từ ngày / Đến ngày). State tạm của 2 ô nằm trong
  /// ValueNotifier để dùng chung giữa phần thân (builder) và chân modal
  /// (footerBuilder).
  Future<void> _onChonKhoangNgay() async {
    FocusScope.of(context).unfocus();

    final tu =
        ValueNotifier<String?>(_tuNgay == null ? null : _isoNgay(_tuNgay!));
    final den =
        ValueNotifier<String?>(_denNgay == null ? null : _isoNgay(_denNgay!));

    final ket = await showAppModal<_KhoangNgay>(
      context,
      title: 'Lọc theo ngày tạo',
      subTitle: 'Chọn khoảng ngày tạo album',
      type: AppModalType.bottomSheet,
      closeOnBackdropClick: true,
      builder: (_) => _LocNgayForm(tu: tu, den: den),
      footerBuilder: (ctx) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(const _KhoangNgay(null, null)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Xóa lọc'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // Blur ô đang nhập dở để DatePickerField kịp commit.
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(ctx).pop(
                  _KhoangNgay(_tuIso(tu.value), _tuIso(den.value)),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Áp dụng',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    if (ket == null || !mounted) return;
    setState(() {
      _tuNgay = ket.tu;
      _denNgay = ket.den;
    });
    unawaited(_taiLai());
  }

  void _xoaFilterNgay() {
    setState(() {
      _tuNgay = null;
      _denNgay = null;
    });
    unawaited(_taiLai());
  }

  /// Nhãn tóm tắt lọc ngày, vd "Ngày tạo: 01/09/2026 – 28/09/2026".
  String get _nhanLocNgay {
    if (_tuNgay != null && _denNgay != null) {
      return 'Ngày tạo: ${_dinhDangNgay(_tuNgay!)} – ${_dinhDangNgay(_denNgay!)}';
    }
    if (_tuNgay != null) return 'Ngày tạo: từ ${_dinhDangNgay(_tuNgay!)}';
    return 'Ngày tạo: đến ${_dinhDangNgay(_denNgay!)}';
  }

  String _dinhDangNgay(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  void _xemChiTiet(Map<String, dynamic> album) {
    Navigator.of(context).pushNamed('/album/detail/${album['id_album']}');
  }

  Future<void> _moThem() async {
    final daTao = await showAddAlbumModal(
      context,
      khachHangOptions: _khachHangOptions,
    );
    // null = đóng modal không lưu; Map/true = đã tạo thành công.
    if (daTao != null && daTao != false) unawaited(_taiLai());
  }

  /// Mở modal "Sửa album" — khớp mẫu `_moThem`: `showEditAlbumModal` (dựng
  /// trên `showAppModal`) trả về `Object?` (Map data / `true` / `null`),
  /// không còn `showModalBottomSheet<bool>` + widget `AlbumEditSheet`
  /// public như bản trước.
  Future<void> _moSua(Map<String, dynamic> album) async {
    final daSua = await showEditAlbumModal(
      context,
      album: album,
      khachHangOptions: _khachHangOptions,
    );
    // null = đóng modal không lưu; Map/true = đã cập nhật thành công.
    if (daSua != null && daSua != false) unawaited(_taiLai());
  }

  /// Mở modal "Phân công phụ trách" — khớp `showAlbumPhanCongModal` mới
  /// (dựng trên `showAppModal`), thay cho `showModalBottomSheet<bool>` +
  /// widget `AlbumPhanCongSheet` public như bản trước. Sheet này không có
  /// nút "Lưu" chung nên không cần kiểm tra giá trị trả về — việc tải lại
  /// danh sách đã do `AlbumEvents.instance.baoCanTaiLai()` (bắn ngay sau
  /// mỗi hành động thành công bên trong sheet) đảm nhiệm.
  Future<void> _moPhanCong(Map<String, dynamic> album) async {
    await showAlbumPhanCongModal(
      context,
      album: album,
      nhanVienOptions: _nhanVienOptions,
    );
  }

  Future<void> _xacNhanDoiTrangThai(
    Map<String, dynamic> album,
    String trangThaiMoi,
    String cauHoi,
  ) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(cauHoi),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (dongY != true) return;

    await _api.doiTrangThai(
      idAlbum: album['id_album'].toString(),
      trangThai: trangThaiMoi,
      onReloadCanThiet: () {
        if (mounted) unawaited(_taiLai());
      },
    );
  }

  Future<void> _xacNhanXoa(Map<String, dynamic> album) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá album'),
        content: Text(
          'Bạn có chắc muốn xoá album "${album['ten_album'] ?? ''}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (dongY != true) return;

    try {
      await _api.xoa(idAlbum: album['id_album'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã xoá album')));
      unawaited(_taiLai());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content:
              Text(e.message.isNotEmpty ? e.message : 'Xoá album thất bại'),
        ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Xoá album thất bại')));
    }
  }

  List<AlbumCardAction> _buildCardActions(Map<String, dynamic> album) {
    final trangThaiHienTai = album['trang_thai']?.toString();
    final albumDaKetThuc =
        trangThaiHienTai == 'hoan_thanh' || trangThaiHienTai == 'huy';

    return [
      if (_coQuyenXem)
        AlbumCardAction(
          nhan: 'Xem chi tiết',
          icon: Icons.visibility_outlined,
          onTap: () => _xemChiTiet(album),
        ),
      if (_coQuyenSua && !albumDaKetThuc)
        AlbumCardAction(
          nhan: 'Sửa',
          icon: Icons.edit_outlined,
          onTap: () => _moSua(album),
        ),
      if (_coQuyenPhanCong && !albumDaKetThuc)
        AlbumCardAction(
          nhan: 'Phân công',
          icon: Icons.person_add_alt_outlined,
          onTap: () => _moPhanCong(album),
        ),
      if (_coQuyenSua && !albumDaKetThuc)
        AlbumCardAction(
          nhan: 'Báo hoàn thành',
          icon: Icons.check_circle_outline,
          onTap: () => _xacNhanDoiTrangThai(
            album,
            'hoan_thanh',
            'Bạn có chắc muốn báo hoàn thành album '
                '"${album['ten_album'] ?? ''}" không?',
          ),
        ),
      if (_coQuyenSua && !albumDaKetThuc)
        AlbumCardAction(
          nhan: 'Báo hủy',
          icon: Icons.cancel_outlined,
          nguyHiem: true,
          onTap: () => _xacNhanDoiTrangThai(
            album,
            'huy',
            'Bạn có chắc muốn hủy album "${album['ten_album'] ?? ''}" không?',
          ),
        ),
      if (_coQuyenXoa)
        AlbumCardAction(
          nhan: 'Xoá',
          icon: Icons.delete_outline,
          nguyHiem: true,
          onTap: () => _xacNhanXoa(album),
        ),
    ];
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // watch để build lại khi quyền trong AuthStore thay đổi.
    final auth = context.watch<AuthStore>();
    final coQuyenXem = auth.coQuyen('ALBUM', 'xem');
    final coQuyenThem = auth.coQuyen('ALBUM', 'them');

    if (!coQuyenXem) {
      return const Center(child: Text('Không có quyền xem'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _Header(
            tongSo: _tongTatCa,
            coQuyenThem: coQuyenThem,
            onThem: _moThem,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OTimKiem(
                  controller: _timKiemController,
                  onChanged: _onTimKiemChanged,
                  hintText: 'Tìm kiếm theo tên album...',
                ),
              ),
              const SizedBox(width: 8),
              _buildNutLoc(),
            ],
          ),
        ),
        if (_dangLocNgay) _buildPillNgay(),
        TabsWithCount(
          options: _tabOptions,
          value: _filterTrangThai,
          onChanged: _onChonTab,
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildBody()),
        if (_items.isNotEmpty) _buildFooter(),
      ],
    );
  }

  /// Nút lọc ngày tạo kế bên ô tìm kiếm.
  Widget _buildNutLoc() {
    final colorScheme = Theme.of(context).colorScheme;
    final dangLoc = _dangLocNgay;
    return Container(
      decoration: BoxDecoration(
        color: dangLoc
            ? AppColors.primary.withOpacity(0.12)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        tooltip:
            dangLoc ? 'Đã lọc theo ngày tạo — bấm để đổi' : 'Lọc theo ngày tạo',
        onPressed: _onChonKhoangNgay,
        icon: Icon(
          Icons.filter_list_rounded,
          color: dangLoc ? AppColors.primary : null,
        ),
      ),
    );
  }

  /// Pill tóm tắt lọc ngày tạo — bấm để đổi, bấm X để bỏ lọc.
  Widget _buildPillNgay() {
    final colorScheme = Theme.of(context).colorScheme;
    final nhan = _nhanLocNgay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _onChonKhoangNgay,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 15, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      nhan,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _xoaFilterNgay,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 10, 8),
                child: Icon(Icons.close_rounded,
                    size: 16, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ErrorRetry(message: _error!, onRetry: _taiLai);
    }

    if (_items.isEmpty) {
      return const EmptyState(text: 'Không có album nào');
    }

    final trangThaiMap = {
      for (final tt in _trangThaiOptions) tt['ma_trang_thai'].toString(): tt,
    };

    return RefreshIndicator(
      onRefresh: () => _taiLai(),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 420,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final album = _items[index];
          return AlbumCard(
            data: album,
            trangThai: trangThaiMap[album['trang_thai']?.toString()],
            onTap: () => _xemChiTiet(album),
            actions: _buildCardActions(album),
          );
        },
      ),
    );
  }

  /// Dòng trạng thái nhỏ dưới danh sách (đang tải thêm / đã hết).
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          _isLoadingMore
              ? 'Đang tải thêm album...'
              : _hasMore
                  ? 'Cuộn xuống để xem thêm'
                  : 'Đã hiển thị tất cả $_totalItems album',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

// ============================================================
// HEADER: tiêu đề + phụ đề (tổng số) + nút "Thêm Album".
// ============================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.tongSo,
    required this.coQuyenThem,
    required this.onThem,
  });

  final int tongSo;
  final bool coQuyenThem;
  final VoidCallback onThem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Album',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '$tongSo album',
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (coQuyenThem) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onThem,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm Album',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// LỌC THEO NGÀY TẠO — helper + form 2 ô DatePickerField (Từ / Đến).
// ============================================================
class _KhoangNgay {
  const _KhoangNgay(this.tu, this.den);
  final DateTime? tu;
  final DateTime? den;
}

String _isoNgay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _tuIso(String? s) {
  if (s == null) return null;
  final p = s.split('-');
  if (p.length != 3) return null;
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Phần thân modal: 2 ô ngày ràng buộc lẫn nhau (Từ <= Đến, không quá hôm
/// nay, không trước 2020).
class _LocNgayForm extends StatelessWidget {
  const _LocNgayForm({required this.tu, required this.den});

  final ValueNotifier<String?> tu;
  final ValueNotifier<String?> den;

  static const String _ngayToiThieu = '2020-01-01';

  @override
  Widget build(BuildContext context) {
    final homNay = _isoNgay(DateTime.now());

    return ListenableBuilder(
      listenable: Listenable.merge([tu, den]),
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DatePickerField(
                label: 'Từ ngày',
                value: tu.value,
                min: _ngayToiThieu,
                max: den.value ?? homNay,
                selectedColor: AppColors.primary,
                onChanged: (v) => tu.value = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DatePickerField(
                label: 'Đến ngày',
                value: den.value,
                min: tu.value ?? _ngayToiThieu,
                max: homNay,
                selectedColor: AppColors.primary,
                onChanged: (v) => den.value = v,
              ),
            ),
          ],
        );
      },
    );
  }
}
