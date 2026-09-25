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
import 'album_events.dart';
import 'album_card.dart';
import 'tabs_with_count.dart';
import 'album_add_sheet.dart';
import 'album_edit_sheet.dart';
import 'album_phan_cong_sheet.dart';

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
  DateTimeRange? _filterKhoangNgayTao;

  // ----- options -----
  List<Map<String, dynamic>> _trangThaiOptions = [];
  List<Map<String, dynamic>> _nhanVienOptions = [];
  List<Map<String, dynamic>> _khachHangOptions = [];
  bool _optionsLoading = false;

  // ----- đếm theo trạng thái (badge trên tab) -----
  Map<String, int> _soLuongTheoTrangThai = {};

  // ----- quyền: đọc qua Provider, không dùng AuthStore.instance -----
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
    setState(() => _optionsLoading = true);

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
    } catch (_) {
      // Lỗi tải options không chặn danh sách chính — khớp React (chỉ log,
      // options rỗng thì dropdown/tab tương ứng rỗng theo).
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
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
        tuNgayTao: _filterKhoangNgayTao?.start.toIso8601String(),
        denNgayTao: _filterKhoangNgayTao?.end.toIso8601String(),
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
    if (_isLoading || _isLoadingMore || !_hasMore || _error != null) return;
    if (!_coQuyenXem) return;

    final vuotNguong = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _scrollThresholdPx;

    if (vuotNguong) unawaited(_taiLai(append: true));
  }

  // ---------------------------------------------------------------------
  // Sự kiện người dùng
  // ---------------------------------------------------------------------

  void _onTimKiemChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceTimKiem, () {
      setState(() => _timKiem = value);
      unawaited(_taiLai());
    });
  }

  void _onChonTab(String? maTrangThai) {
    setState(() => _filterTrangThai = maTrangThai);
    unawaited(_taiLai());
  }

  Future<void> _onChonKhoangNgay() async {
    final ket = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterKhoangNgayTao,
    );
    if (ket == null) return;
    setState(() => _filterKhoangNgayTao = ket);
    unawaited(_taiLai());
  }

  void _xoaFilterNgay() {
    setState(() => _filterKhoangNgayTao = null);
    unawaited(_taiLai());
  }

  void _xemChiTiet(Map<String, dynamic> album) {
    Navigator.of(context).pushNamed('/album/detail/${album['id_album']}');
  }

  Future<void> _moThem() async {
    final daTao = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AlbumAddSheet(khachHangOptions: _khachHangOptions),
    );
    if (daTao == true) unawaited(_taiLai());
  }

  Future<void> _moSua(Map<String, dynamic> album) async {
    final daSua = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AlbumEditSheet(
        album: album,
        khachHangOptions: _khachHangOptions,
      ),
    );
    if (daSua == true) unawaited(_taiLai());
  }

  Future<void> _moPhanCong(Map<String, dynamic> album) async {
    final daPhanCong = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AlbumPhanCongSheet(
        album: album,
        nhanVienOptions: _nhanVienOptions,
      ),
    );
    if (daPhanCong == true) unawaited(_taiLai());
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
    // await _api.xoa(idAlbum: album['id_album'].toString());
    unawaited(_taiLai());
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
      if (_coQuyenPhanCong && !albumDaKetThuc)
        AlbumCardAction(
          nhan: 'Phân công',
          icon: Icons.person_add_alt_outlined,
          onTap: () => _moPhanCong(album),
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
    // Đăng ký rebuild khi quyền trong AuthStore thay đổi (đăng nhập lại,
    // đổi vai trò...) — khớp mẫu context.watch<AuthStore>() ở
    // DanhMucKhachHangListView. Các getter _coQuyen* dùng context.read bên
    // trong callback vẫn hoạt động bình thường; dòng watch này chỉ để
    // build() tự chạy lại khi AuthStore notifyListeners().
    context.watch<AuthStore>();

    final trangThaiMap = {
      for (final tt in _trangThaiOptions) tt['ma_trang_thai'].toString(): tt,
    };

    return RefreshIndicator(
      onRefresh: () => _taiLai(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: TabsWithCount(
              options: _tabOptions,
              value: _filterTrangThai,
              onChanged: _onChonTab,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ThanhLocDelegate(
              child: _buildThanhLoc(context),
            ),
          ),
          _buildBody(trangThaiMap),
        ],
      ),
    );
  }

  Widget _buildThanhLoc(BuildContext context) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _timKiemController,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm theo tên album...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _onTimKiemChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _filterKhoangNgayTao == null
                  ? 'Lọc theo ngày tạo'
                  : 'Đã lọc theo ngày tạo — bấm để đổi',
              onPressed: _onChonKhoangNgay,
              icon: Icon(
                Icons.filter_alt_outlined,
                color: _filterKhoangNgayTao != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            if (_filterKhoangNgayTao != null)
              IconButton(
                tooltip: 'Bỏ lọc ngày',
                onPressed: _xoaFilterNgay,
                icon: const Icon(Icons.close),
              ),
            if (_coQuyenThem)
              FilledButton.icon(
                onPressed: _moThem,
                icon: const Icon(Icons.add),
                label: const Text('Thêm album'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, Map<String, dynamic>> trangThaiMap) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      final text = !_coQuyenXem
          ? 'Bạn không có quyền xem dữ liệu này'
          : (_error ?? 'Không có album nào');
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text),
              if (_error != null && _coQuyenXem) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _taiLai(),
                  child: const Text('Thử lại'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final soCot = _soCotTheoBeRong(constraints.crossAxisExtent);
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: soCot,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = _items[index];
                    return AlbumCard(
                      data: album,
                      trangThai: trangThaiMap[album['trang_thai']?.toString()],
                      onTap: () => _xemChiTiet(album),
                      actions: _buildCardActions(album),
                    );
                  },
                  childCount: _items.length,
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
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
            ),
          ),
        ],
      ),
    );
  }

  int _soCotTheoBeRong(double beRong) {
    if (beRong >= 1200) return 4;
    if (beRong >= 900) return 3;
    if (beRong >= 600) return 2;
    return 1;
  }
}

/// SliverPersistentHeader delegate cho thanh tìm kiếm/filter dính (sticky)
/// — thay cho IntersectionObserver + backdrop-blur bên React. `pinned: true`
/// ở CustomScrollView đã tự tạo hiệu ứng dính, `Material(elevation: 2)` tạo
/// bóng đổ tương đương trạng thái `isStuck` bên React.
class _ThanhLocDelegate extends SliverPersistentHeaderDelegate {
  _ThanhLocDelegate({required this.child});

  final Widget child;
  static const double _height = 64;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _ThanhLocDelegate oldDelegate) => false;
}
