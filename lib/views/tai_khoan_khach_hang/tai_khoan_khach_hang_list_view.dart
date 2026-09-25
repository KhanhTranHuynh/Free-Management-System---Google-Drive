import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../apis/services/danh_muc_khach_hang_api.dart';
import '../../stores/auth_store.dart';
import 'add_tai_khoan_khach_hang.dart';
import 'edit_tai_khoan_khach_hang.dart';

/// Danh sách khách hàng. Toàn bộ state (search/filter/sort/phân trang) +
/// gọi API nằm cục bộ trong View này — AuthStore chỉ được đọc để lấy quyền
/// (KHACH_HANG: xem/thêm/sửa/xóa). Dữ liệu để dạng Map thô, đọc field trực
/// tiếp khi cần — giống pattern nhan_vien_list_view.dart.
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
  Timer? _debounce;

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _phanTrang = const {};
  bool _isLoading = false;
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

  String? get _sapXep =>
      _sortColumn == null ? null : '$_sortColumn:${_sortType.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    unawaited(_taiDanhMuc());
    unawaited(_taiLai());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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

  Future<void> _taiLai() async {
    final id = ++_requestId;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final body = await _api.layDanhSach(
        timKiem: _timKiem,
        trang: _trang,
        soLuong: _soLuong,
        trangThai: _filterTrangThai,
        danhMucKhachHangId: _filterDanhMuc,
        choPhepDangNhapPortal: _filterChoPhepPortal,
        sapXep: _sapXep,
      );
      if (!mounted || id != _requestId) return;

      setState(() {
        _items = _readList(body);
        _phanTrang = _readPage(body);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _items = [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _items = [];
        _isLoading = false;
      });
    }
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
      // TODO: xác nhận đúng tên field id thật (đang giả định 'id', fallback
      // 'id_tai_khoan_khach_hang') — khớp payload edit_tai_khoan_khach_hang.dart.
      final id = item['id'] ?? item['id_tai_khoan_khach_hang'];
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
      setState(() {
        _timKiem = value.trim();
        _trang = 1;
      });
      unawaited(_taiLai());
    });
  }

  void _onFilterTrangThaiChanged(bool? value) {
    setState(() {
      _filterTrangThai = value;
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  void _onFilterDanhMucChanged(String? value) {
    setState(() {
      _filterDanhMuc = value;
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  void _onFilterPortalChanged(bool? value) {
    setState(() {
      _filterChoPhepPortal = value;
      _trang = 1;
    });
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
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  void _goToPage(int trang) {
    if (trang < 1 || trang > _tongTrang || trang == _trang) return;
    setState(() => _trang = trang);
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
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Tìm theo tên, email, số điện thoại...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildSortMenu(),
                  if (coQuyenThem) ...[
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: _moModalThem,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm'),
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
        if (_tongTrang > 1) _buildPagination(),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          final sdtDangNhap =
              item['so_dien_thoai_dang_nhap']?.toString() ?? '--';
          final tenDanhMuc = item['ten_danh_muc']?.toString() ?? '--';
          final trangThai = item['trang_thai'] == true;

          final canAct = coQuyenSua || coQuyenXoa;

          return ListTile(
            title: Text(item['ho_ten']?.toString() ?? '--'),
            subtitle: Text(
              '$sdtDangNhap · '
              '${item['email']?.toString() ?? '--'} · '
              '$tenDanhMuc · '
              '${trangThai ? 'Hoạt động' : 'Khóa'}',
            ),
            trailing: canAct
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'sua') _moModalSua(item);
                      if (value == 'xoa') _xacNhanXoa(item);
                    },
                    itemBuilder: (context) => [
                      if (coQuyenSua)
                        const PopupMenuItem(value: 'sua', child: Text('Sửa')),
                      if (coQuyenXoa)
                        const PopupMenuItem(value: 'xoa', child: Text('Xoá')),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _trang > 1 ? () => _goToPage(_trang - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Trang $_trang/$_tongTrang'),
          IconButton(
            onPressed: _trang < _tongTrang ? () => _goToPage(_trang + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
