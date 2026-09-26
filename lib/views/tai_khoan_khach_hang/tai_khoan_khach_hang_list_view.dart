import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// TODO: xác nhận package url_launcher đã có trong pubspec.yaml chưa —
// dùng để bấm "Gọi ngay" mở app quay số. Nếu chưa có, chạy:
//   flutter pub add url_launcher
import 'package:url_launcher/url_launcher.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../apis/services/danh_muc_khach_hang_api.dart';
import '../../stores/auth_store.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án (giống nhan_vien_list_view.dart / danh_muc_khach_hang_list_view.dart).
import '../../configs/app_colors.dart';
import '../../components/o_tim_kiem.dart';
import 'add_tai_khoan_khach_hang.dart';
import 'edit_tai_khoan_khach_hang.dart';

/// Danh sách khách hàng. Toàn bộ state (search/filter/sort/phân trang) +
/// gọi API nằm cục bộ trong View này — AuthStore chỉ được đọc để lấy quyền
/// (KHACH_HANG: xem/thêm/sửa/xóa). Dữ liệu để dạng Map thô, đọc field trực
/// tiếp khi cần.
///
/// UI đổi sang dạng card (giống mẫu thiết kế mới, khớp NhanVienListView /
/// DanhMucKhachHangListView): mỗi khách hàng 1 card có avatar tròn viết
/// tắt tên, chip danh mục, chấm trạng thái, số ĐT đăng nhập (có nút "Gọi
/// ngay"), số ĐT liên hệ, email (có nút copy).
///
/// Danh sách giờ dùng infinite scroll (cuộn gần cuối tự tải thêm trang
/// kế) thay cho nút bấm số trang; ô tìm kiếm dùng chung OTimKiem.
class TaiKhoanKhachHangListView extends StatefulWidget {
  const TaiKhoanKhachHangListView({super.key});

  @override
  State<TaiKhoanKhachHangListView> createState() =>
      _TaiKhoanKhachHangListViewState();
}

class _TaiKhoanKhachHangListViewState extends State<TaiKhoanKhachHangListView> {
  static const int _soLuong = 10;

  /// Các cột cho phép sắp xếp (khớp bản React: chỉ ho_ten, trang_thai
  /// không disableSortBy).
  static const List<(String, String)> _cotSapXep = [
    ('ho_ten', 'Họ tên'),
    ('trang_thai', 'Trạng thái'),
  ];

  static const List<(bool?, String)> _trangThaiOptions = [
    (null, 'Tất cả trạng thái'),
    (true, 'Hoạt động'),
    (false, 'Khóa'),
  ];

  static const List<(bool?, String)> _portalOptions = [
    (null, 'Tất cả'),
    (true, 'Có portal'),
    (false, 'Không portal'),
  ];

  final _api = TaiKhoanKhachHangApi(ApiRequestManager.instance);
  final _danhMucApi = DanhMucKhachHangApi(ApiRequestManager.instance);
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _phanTrang = const {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _requestId = 0;

  String _timKiem = '';
  bool? _filterTrangThai;
  String? _filterDanhMuc; // id_danh_muc_khach_hang, null = tất cả
  bool? _filterChoPhepPortal;
  int _trang = 1;
  String? _sortColumn;
  String _sortType = 'ASC';

  // Options danh mục (nạp 1 lần, dùng lại cho filter + modal thêm/sửa).
  List<Map<String, dynamic>> _danhMucOptions = [];
  bool _danhMucLoading = false;
  Future<void>? _danhMucFuture;

  bool _dangMoModal = false;

  int get _tongSo => (_phanTrang['tong_so'] as num?)?.toInt() ?? 0;
  int get _tongTrang => _tongSo <= 0 ? 1 : (_tongSo / _soLuong).ceil();
  bool get _conTrangSau => _trang < _tongTrang;

  String? get _sapXep =>
      _sortColumn == null ? null : '$_sortColumn:${_sortType.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_taiDanhMuc());
    unawaited(_taiLai());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> body) {
    final raw = body['du_lieu'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _readPage(Map<String, dynamic> body) {
    final raw = body['phan_trang'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  void _thongBao(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _taiDanhMuc() {
    return _danhMucFuture ??=
        _fetchDanhMuc().whenComplete(() => _danhMucFuture = null);
  }

  Future<void> _fetchDanhMuc() async {
    if (mounted) setState(() => _danhMucLoading = true);
    try {
      final body = await _danhMucApi.layDanhSach(
        trang: 1,
        soLuong: 100,
        dangHoatDong: true,
      );
      if (!mounted) return;
      setState(() {
        _danhMucOptions = _readList(body)
            .where((dm) => dm['id_danh_muc_khach_hang'] != null)
            .toList();
        _danhMucLoading = false;
      });
    } catch (e, st) {
      debugPrint('[KhachHang] LOI khi tai danh sach danh muc: $e\n$st');
      if (!mounted) return;
      setState(() {
        _danhMucOptions = [];
        _danhMucLoading = false;
      });
    }
  }

  /// Tải trang 1 (reload toàn bộ) — dùng khi mở màn, đổi filter/sort/tìm
  /// kiếm hoặc kéo-để-làm-mới.
  Future<void> _taiLai() async {
    final id = ++_requestId;
    _trang = 1;

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
    });

    try {
      final body = await _api.layDanhSach(
        timKiem: _timKiem,
        trang: 1,
        soLuong: _soLuong,
        trangThai: _filterTrangThai,
        danhMucKhachHangId: _filterDanhMuc,
        choPhepDangNhapPortal: _filterChoPhepPortal,
        sapXep: _sapXep,
      );
      if (!mounted || id != _requestId) return;

      setState(() {
        _items
          ..clear()
          ..addAll(_readList(body));
        _phanTrang = _readPage(body);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _items.clear();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _items.clear();
        _isLoading = false;
      });
    }
  }

  /// Tải trang kế tiếp (append) — gọi khi cuộn gần tới cuối danh sách.
  Future<void> _taiThem() async {
    if (_isLoading || _isLoadingMore || !_conTrangSau) return;
    final id = _requestId;
    setState(() => _isLoadingMore = true);

    try {
      final body = await _api.layDanhSach(
        timKiem: _timKiem,
        trang: _trang + 1,
        soLuong: _soLuong,
        trangThai: _filterTrangThai,
        danhMucKhachHangId: _filterDanhMuc,
        choPhepDangNhapPortal: _filterChoPhepPortal,
        sapXep: _sapXep,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _items.addAll(_readList(body));
        _phanTrang = _readPage(body);
        _trang += 1;
        _isLoadingMore = false;
      });
    } catch (_) {
      // Toast lỗi đã được hiện ở tầng apis/ (notifyApiByCode).
      if (!mounted || id != _requestId) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _taiThem();
  }

  void reload() => unawaited(_taiLai());

  Future<bool> _dambaoDanhMucDaTai() async {
    if (_danhMucOptions.isEmpty) await _taiDanhMuc();
    if (!mounted) return false;
    if (_danhMucOptions.isEmpty) {
      _thongBao('Không tải được danh sách danh mục. Vui lòng thử lại.');
      return false;
    }
    return true;
  }

  Future<void> _moModalThem() async {
    if (_dangMoModal) return;
    _dangMoModal = true;
    try {
      if (!await _dambaoDanhMucDaTai()) return;
      if (!context.mounted) return;

      final ok = await showAddTaiKhoanKhachHangModal(
        context,
        danhMucOptions: _danhMucOptions,
      );
      if (!context.mounted) return;

      if (ok == true) {
        _thongBao('Thêm khách hàng thành công');
        reload();
      }
    } finally {
      _dangMoModal = false;
    }
  }

  Future<void> _moModalSua(Map<String, dynamic> item) async {
    if (_dangMoModal) return;
    _dangMoModal = true;
    try {
      if (!await _dambaoDanhMucDaTai()) return;
      if (!context.mounted) return;

      final ok = await showEditTaiKhoanKhachHangModal(
        context,
        khachHang: item,
        danhMucOptions: _danhMucOptions,
      );
      if (!context.mounted) return;

      if (ok == true) {
        _thongBao('Cập nhật khách hàng thành công');
        reload();
      }
    } finally {
      _dangMoModal = false;
    }
  }

  /// Hỏi xác nhận rồi gọi API xoá; reload nếu thành công.
  Future<void> _xacNhanXoa(Map<String, dynamic> item) async {
    if (_dangMoModal) return;
    final ten = item['ho_ten']?.toString() ?? 'khách hàng này';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá khách hàng'),
        content: Text(
            'Bạn có chắc muốn xoá "$ten"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _dangMoModal = true;
    try {
      // TODO: xác nhận đúng tên field id thật (đang giả định
      // 'id_tai_khoan_khach_hang', fallback 'id') — khớp payload
      // edit_tai_khoan_khach_hang.dart. Xem lại theo đúng bài học ở
      // danh mục khách hàng: backend thường yêu cầu đúng tên field dài,
      // không phải 'id' trơn.
      final id = item['id_tai_khoan_khach_hang'] ?? item['id'];
      await _api.xoa(id);
      if (!mounted) return;
      _thongBao('Đã xoá khách hàng');
      reload();
    } on ApiException {
      // toast lỗi đã hiển thị ở tầng API
    } catch (_) {
      if (mounted) _thongBao('Xoá khách hàng thất bại. Vui lòng thử lại.');
    } finally {
      _dangMoModal = false;
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _timKiem = value.trim();
      unawaited(_taiLai());
    });
  }

  void _onFilterTrangThaiChanged(bool? value) {
    setState(() => _filterTrangThai = value);
    unawaited(_taiLai());
  }

  void _onFilterDanhMucChanged(String? value) {
    setState(() => _filterDanhMuc = value);
    unawaited(_taiLai());
  }

  void _onFilterPortalChanged(bool? value) {
    setState(() => _filterChoPhepPortal = value);
    unawaited(_taiLai());
  }

  void _onSortColumnTap(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortType = _sortType == 'ASC' ? 'DESC' : 'ASC';
      } else {
        _sortColumn = column;
        _sortType = 'ASC';
      }
    });
    unawaited(_taiLai());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final coQuyenXem = auth.coQuyen('KHACH_HANG', 'xem');
    final coQuyenThem = auth.coQuyen('KHACH_HANG', 'them');
    final coQuyenSua = auth.coQuyen('KHACH_HANG', 'sua');
    final coQuyenXoa = auth.coQuyen('KHACH_HANG', 'xoa');

    if (!coQuyenXem) {
      return const Center(child: Text('Không có quyền xem'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OTimKiem(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      hintText: 'Tìm theo tên, email, số điện thoại...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSortMenu(),
                  if (coQuyenThem) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _moModalThem,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Thêm',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDanhMucDropdown()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<bool?>(
                      initialValue: _filterTrangThai,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final opt in _trangThaiOptions)
                          DropdownMenuItem(
                            value: opt.$1,
                            child: Text(opt.$2),
                          ),
                      ],
                      onChanged: _onFilterTrangThaiChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<bool?>(
                initialValue: _filterChoPhepPortal,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Cho phép đăng nhập portal',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final opt in _portalOptions)
                    DropdownMenuItem(value: opt.$1, child: Text(opt.$2)),
                ],
                onChanged: _onFilterPortalChanged,
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(coQuyenSua, coQuyenXoa)),
      ],
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Sắp xếp',
      icon: const Icon(Icons.sort),
      onSelected: _onSortColumnTap,
      itemBuilder: (_) => [
        for (final col in _cotSapXep)
          PopupMenuItem<String>(
            value: col.$1,
            child: Row(
              children: [
                Expanded(child: Text(col.$2)),
                if (_sortColumn == col.$1)
                  Icon(
                    _sortType == 'ASC'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Dropdown "Danh mục" tách riêng để xử lý loading mà không sinh 2 item
  /// cùng value:null — cùng lý do như _buildVaiTroDropdown() bên
  /// nhan_vien_list_view.dart.
  Widget _buildDanhMucDropdown() {
    final validValues = <String?>{
      null,
      ..._danhMucOptions.map((dm) => dm['id_danh_muc_khach_hang']?.toString()),
    };
    final currentValue =
        validValues.contains(_filterDanhMuc) ? _filterDanhMuc : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey('filter-danh-muc-${_danhMucOptions.length}-$currentValue'),
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Danh mục',
        border: const OutlineInputBorder(),
        suffixIcon: _danhMucLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Tất cả danh mục')),
        for (final dm in _danhMucOptions)
          DropdownMenuItem(
            value: dm['id_danh_muc_khach_hang']?.toString(),
            child: Text(dm['ten_hien_thi']?.toString() ?? ''),
          ),
      ],
      onChanged: _danhMucLoading ? null : _onFilterDanhMucChanged,
    );
  }

  Widget _buildBody(bool coQuyenSua, bool coQuyenXoa) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _taiLai, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return RefreshIndicator(
      onRefresh: _taiLai,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _KhachHangCard(
              item: item,
              coQuyenSua: coQuyenSua,
              coQuyenXoa: coQuyenXoa,
              onSua: () => _moModalSua(item),
              onXoa: () => _xacNhanXoa(item),
              onThongBao: _thongBao,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// CARD 1 KHÁCH HÀNG — khớp mẫu: avatar tròn viết tắt tên, chip danh mục,
// chấm trạng thái, số ĐT đăng nhập (có nút "Gọi ngay"), số ĐT liên hệ,
// email (có nút copy). Footer là nút "Sửa" (pill) + menu "..." cho Xoá.
// ============================================================
class _KhachHangCard extends StatelessWidget {
  const _KhachHangCard({
    required this.item,
    required this.coQuyenSua,
    required this.coQuyenXoa,
    required this.onSua,
    required this.onXoa,
    required this.onThongBao,
  });

  final Map<String, dynamic> item;
  final bool coQuyenSua;
  final bool coQuyenXoa;
  final VoidCallback onSua;
  final VoidCallback onXoa;
  final void Function(String message) onThongBao;

  /// Lấy 1-2 ký tự viết tắt từ họ tên, dùng cho avatar tròn (vd
  /// "test khách hàng" -> "TK", "An" -> "A").
  String _vietTat(String hoTen) {
    final parts =
        hoTen.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Future<void> _goiNgay(BuildContext context, String soDienThoai) async {
    final uri = Uri(scheme: 'tel', path: soDienThoai);
    final ok = await launchUrl(uri);
    if (!ok) onThongBao('Không thể mở ứng dụng gọi điện.');
  }

  void _copyEmail(String email) {
    Clipboard.setData(ClipboardData(text: email));
    onThongBao('Đã sao chép email');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final hoTen = item['ho_ten']?.toString() ?? '';
    // TODO: xác nhận đúng tên field số ĐT liên hệ thật từ API (đang giả
    // định 'so_dien_thoai_lien_he').
    final sdtDangNhap = item['so_dien_thoai_dang_nhap']?.toString() ?? '';
    final sdtLienHe = item['so_dien_thoai_lien_he']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    final tenDanhMuc = item['ten_danh_muc']?.toString() ?? '';
    final hoatDong = item['trang_thai'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  _vietTat(hoTen),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hoTen,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (tenDanhMuc.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9B8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    size: 13, color: Color(0xFFB8874A)),
                                const SizedBox(width: 4),
                                Text(
                                  tenDanhMuc,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: Color(0xFF8A6428),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _StatusDot(hoatDong: hoatDong),
                      ],
                    ),
                  ],
                ),
              ),
              if (coQuyenSua) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSua,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Sửa'),
                ),
              ],
              if (coQuyenXoa) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onXoa,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side:
                        BorderSide(color: Theme.of(context).colorScheme.error),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Xoá'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (sdtDangNhap.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.phone_rounded,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('SĐT ĐN: ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      sdtDangNhap,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _goiNgay(context, sdtDangNhap),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gọi ngay',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.phone_forwarded_outlined,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('SĐT Liên hệ: ',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                Expanded(
                  child: Text(
                    sdtLienHe.isEmpty ? '--' : sdtLienHe,
                    style: TextStyle(
                      color: sdtLienHe.isEmpty
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (email.isNotEmpty)
            Row(
              children: [
                Icon(Icons.email_outlined,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(email, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () => _copyEmail(email),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.hoatDong});

  final bool hoatDong;

  @override
  Widget build(BuildContext context) {
    final color = hoatDong ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          hoatDong ? 'Hoạt động' : 'Khóa',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ],
    );
  }
}
