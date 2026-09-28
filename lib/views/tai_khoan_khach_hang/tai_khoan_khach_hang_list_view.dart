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
// trong dự án (giống nhan_vien_list_view.dart).
import '../../configs/app_colors.dart';
import '../../utils/avatar_util.dart';
import '../../components/o_tim_kiem.dart';
import '../../components/modal_loc_sap_xep.dart';
import '../../components/empty_state.dart';
import '../../components/error_retry.dart';
import '../../components/status_indicator.dart';
import 'add_tai_khoan_khach_hang.dart';
import 'edit_tai_khoan_khach_hang.dart';

/// Danh sách khách hàng. Toàn bộ state (search/filter/sort/phân trang) +
/// gọi API nằm cục bộ trong View này — AuthStore chỉ được đọc để lấy quyền
/// (KHACH_HANG: xem/thêm/sửa/xóa). Dữ liệu để dạng Map thô.
///
/// UI đã đồng bộ theo NhanVienListView:
/// - Header: tiêu đề + phụ đề (tổng số) + nút "Thêm".
/// - Hàng tìm kiếm + nút "..." mở modal "Lọc & sắp xếp" DÙNG CHUNG
///   (`showModalLocSapXep`); 3 nhóm lọc (Danh mục / Trạng thái / Portal)
///   mỗi nhóm 1 dòng chip, sắp xếp gộp thành 1 dropdown.
/// - Pill tóm tắt lọc/sắp xếp bên dưới (bấm cũng mở modal) thay cho 3
///   dropdown to chiếm chỗ như trước.
/// - Card dùng avatar màu (avatar_util), StatusIndicator, EmptyState,
///   ErrorRetry dùng chung. Nút Sửa / Xoá hiển thị trực tiếp trên card.
/// Vẫn giữ infinite scroll (cuộn gần cuối tự tải thêm trang kế).
class TaiKhoanKhachHangListView extends StatefulWidget {
  const TaiKhoanKhachHangListView({super.key});

  @override
  State<TaiKhoanKhachHangListView> createState() =>
      _TaiKhoanKhachHangListViewState();
}

class _TaiKhoanKhachHangListViewState extends State<TaiKhoanKhachHangListView> {
  static const int _soLuong = 10;

  /// Các cột cho phép sắp xếp (khớp bản React: ho_ten, trang_thai).
  static const List<(String, String)> _cotSapXep = [
    ('ho_ten', 'Họ tên'),
    ('trang_thai', 'Trạng thái'),
  ];

  static const List<(bool?, String, Color?)> _trangThaiOptions = [
    (null, 'Tất cả trạng thái', null),
    (true, 'Hoạt động', Color(0xFF16A34A)),
    (false, 'Khóa', Color(0xFF9CA3AF)),
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

  // Options danh mục (nạp 1 lần, dùng lại cho modal lọc + modal thêm/sửa).
  List<Map<String, dynamic>> _danhMucOptions = [];
  Future<void>? _danhMucFuture;

  bool _dangMoModal = false;

  // Tổng số khách hàng cho phụ đề header — chỉ cập nhật từ lần tải KHÔNG
  // lọc/tìm kiếm gì, để khi đang lọc phụ đề không bị nhảy theo kết quả lọc.
  int _tongSoTatCa = 0;

  int get _tongSo => (_phanTrang['tong_so'] as num?)?.toInt() ?? 0;
  int get _tongTrang => _tongSo <= 0 ? 1 : (_tongSo / _soLuong).ceil();
  bool get _conTrangSau => _trang < _tongTrang;

  String? get _sapXep =>
      _sortColumn == null ? null : '$_sortColumn:${_sortType.toLowerCase()}';

  // ----- helpers cho modal "Lọc & sắp xếp" dùng chung -----

  List<TuyChonSapXep> get _tuyChonSapXep => [
        const TuyChonSapXep(value: '', label: 'Mặc định'),
        for (final col in _cotSapXep) ...[
          TuyChonSapXep(value: '${col.$1}:ASC', label: '${col.$2} (A → Z)'),
          TuyChonSapXep(value: '${col.$1}:DESC', label: '${col.$2} (Z → A)'),
        ],
      ];

  String get _sapXepDangChonHienTai =>
      _sortColumn == null ? '' : '$_sortColumn:$_sortType';

  void _onDoiSapXep(String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _sortColumn = null;
        _sortType = 'ASC';
      } else {
        final parts = value.split(':');
        _sortColumn = parts[0];
        _sortType = parts.length > 1 ? parts[1] : 'ASC';
      }
    });
    unawaited(_taiLai());
  }

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
      });
    } catch (e, st) {
      debugPrint('[KhachHang] LOI khi tai danh sach danh muc: $e\n$st');
      if (!mounted) return;
      setState(() => _danhMucOptions = []);
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

      final phanTrang = _readPage(body);
      final khongLoc = _timKiem.isEmpty &&
          _filterTrangThai == null &&
          _filterDanhMuc == null &&
          _filterChoPhepPortal == null;

      setState(() {
        _items
          ..clear()
          ..addAll(_readList(body));
        _phanTrang = phanTrang;
        if (khongLoc) {
          _tongSoTatCa =
              (phanTrang['tong_so'] as num?)?.toInt() ?? _items.length;
        }
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
      // edit_tai_khoan_khach_hang.dart.
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
    if (value == _filterTrangThai) return;
    setState(() => _filterTrangThai = value);
    unawaited(_taiLai());
  }

  void _onFilterDanhMucChanged(String? value) {
    if (value == _filterDanhMuc) return;
    setState(() => _filterDanhMuc = value);
    unawaited(_taiLai());
  }

  void _onFilterPortalChanged(bool? value) {
    if (value == _filterChoPhepPortal) return;
    setState(() => _filterChoPhepPortal = value);
    unawaited(_taiLai());
  }

  /// Xoá toàn bộ lọc + sắp xếp đang áp dụng, quay về mặc định.
  void _xoaLoc() {
    setState(() {
      _filterDanhMuc = null;
      _filterTrangThai = null;
      _filterChoPhepPortal = null;
      _sortColumn = null;
      _sortType = 'ASC';
    });
    unawaited(_taiLai());
  }

  /// Mở modal Lọc & sắp xếp DÙNG CHUNG (components/modal_loc_sap_xep.dart).
  /// Mỗi lần chọn chip/dropdown, callback tương ứng tự setState + _taiLai().
  Future<void> _moModalLocSapXep() async {
    FocusScope.of(context).unfocus();
    // Đảm bảo options danh mục đã có trước khi vẽ modal (modal nhận bản
    // chụp options, không tự cập nhật sau đó).
    if (_danhMucOptions.isEmpty) {
      await _taiDanhMuc();
      if (!mounted) return;
    }
    await showModalLocSapXep(
      context,
      title: 'Lọc & sắp xếp',
      tuyChonSapXep: _tuyChonSapXep,
      sapXepDangChon: _sapXepDangChonHienTai,
      onDoiSapXep: _onDoiSapXep,
      nhomLoc: [
        NhomLoc(
          tieuDe: 'Danh mục',
          options: [
            const TuyChonLoc(value: null, label: 'Tất cả danh mục'),
            for (final dm in _danhMucOptions)
              TuyChonLoc(
                value: dm['id_danh_muc_khach_hang']?.toString(),
                label: dm['ten_hien_thi']?.toString() ?? '',
              ),
          ],
          dangChon: _filterDanhMuc,
          onChon: _onFilterDanhMucChanged,
        ),
        NhomLoc(
          tieuDe: 'Trạng thái',
          options: [
            for (final opt in _trangThaiOptions)
              TuyChonLoc(
                value: opt.$1?.toString(),
                label: opt.$2,
                mau: opt.$3,
              ),
          ],
          dangChon: _filterTrangThai?.toString(),
          onChon: (value) =>
              _onFilterTrangThaiChanged(value == null ? null : value == 'true'),
        ),
        NhomLoc(
          tieuDe: 'Đăng nhập portal',
          options: [
            for (final opt in _portalOptions)
              TuyChonLoc(value: opt.$1?.toString(), label: opt.$2),
          ],
          dangChon: _filterChoPhepPortal?.toString(),
          onChon: (value) =>
              _onFilterPortalChanged(value == null ? null : value == 'true'),
        ),
      ],
      onXoaLoc: _xoaLoc,
    );
  }

  /// Nhãn tóm tắt bộ lọc/sắp xếp hiện tại — hiện ngay ngoài danh sách.
  String get _nhanTomTat {
    final danhMuc = _filterDanhMuc == null
        ? 'Tất cả danh mục'
        : (_danhMucOptions
                .firstWhere(
                    (dm) =>
                        dm['id_danh_muc_khach_hang']?.toString() ==
                        _filterDanhMuc,
                    orElse: () =>
                        {'ten_hien_thi': _filterDanhMuc})['ten_hien_thi']
                ?.toString() ??
            _filterDanhMuc!);
    final trangThai = _filterTrangThai == null
        ? 'Tất cả trạng thái'
        : (_filterTrangThai! ? 'Hoạt động' : 'Khóa');
    final parts = <String>[danhMuc, trangThai];
    if (_filterChoPhepPortal != null) {
      parts.add(_filterChoPhepPortal! ? 'Có portal' : 'Không portal');
    }
    if (_sortColumn != null) {
      final col = _cotSapXep.firstWhere((c) => c.$1 == _sortColumn,
          orElse: () => (_sortColumn!, _sortColumn!));
      parts.add('Sắp xếp: ${col.$2} ${_sortType == 'ASC' ? '↑' : '↓'}');
    }
    return parts.join(' · ');
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

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _Header(
            tongSo: _tongSoTatCa,
            coQuyenThem: coQuyenThem,
            onThem: _moModalThem,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OTimKiem(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  hintText: 'Tìm theo tên, email, số điện thoại...',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  tooltip: 'Lọc & sắp xếp',
                  onPressed: _moModalLocSapXep,
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ),
            ],
          ),
        ),
        // Tóm tắt lọc + sắp xếp hiện tại (bấm vào cũng mở lại modal).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: InkWell(
            onTap: _moModalLocSapXep,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 15, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _nhanTomTat,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(coQuyenSua, coQuyenXoa)),
      ],
    );
  }

  Widget _buildBody(bool coQuyenSua, bool coQuyenXoa) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ErrorRetry(message: _error!, onRetry: _taiLai);
    }

    if (_items.isEmpty) {
      return const EmptyState(text: 'Không có dữ liệu');
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
// HEADER: tiêu đề + phụ đề (tổng số) + nút "Thêm".
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
                'Khách hàng',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '$tongSo khách hàng',
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
            label: const Text('Thêm Khách Hàng',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// CARD 1 KHÁCH HÀNG — avatar màu viết tắt tên, badge danh mục, trạng thái,
// nút Sửa + nút Xoá hiển thị trực tiếp (xếp dọc bên phải); bên dưới là các
// dòng liên hệ (SĐT đăng nhập có "Gọi ngay", SĐT liên hệ, email có copy).
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

  Future<void> _goiNgay(String soDienThoai) async {
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
    final hoTenHienThi = hoTen.isEmpty ? '--' : hoTen;
    // TODO: xác nhận đúng tên field số ĐT liên hệ thật từ API (đang giả
    // định 'so_dien_thoai_lien_he').
    final sdtDangNhap = item['so_dien_thoai_dang_nhap']?.toString() ?? '';
    final sdtLienHe = item['so_dien_thoai_lien_he']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    final tenDanhMuc = item['ten_danh_muc']?.toString() ?? '';
    final hoatDong = item['trang_thai'] == true;

    final avatarIdx = avatarIndex(hoTenHienThi);
    final avatarBg = parseHexColor(
      item['mau_sac']?.toString(),
      fallback: avatarPalette[avatarIdx],
    );
    final avatarFg = contrastFg(avatarBg);

    final danhMucIdx = avatarIndex(tenDanhMuc);

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
                radius: 22,
                backgroundColor: avatarBg,
                child: Text(
                  layChuCaiDau(hoTenHienThi),
                  style: TextStyle(
                    color: avatarFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hoTenHienThi,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (tenDanhMuc.isNotEmpty)
                          _DanhMucBadge(
                            ten: tenDanhMuc,
                            bg: avatarPalette[danhMucIdx],
                            fg: avatarPaletteFg[danhMucIdx],
                          ),
                        StatusIndicator(
                          label: hoatDong ? 'Hoạt động' : 'Khóa',
                          color: hoatDong
                              ? AppColors.success
                              : const Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (coQuyenSua || coQuyenXoa) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (coQuyenSua)
                      OutlinedButton(
                        onPressed: onSua,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                              color: AppColors.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Sửa'),
                      ),
                    if (coQuyenSua && coQuyenXoa) const SizedBox(width: 6),
                    if (coQuyenXoa)
                      OutlinedButton(
                        onPressed: onXoa,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                              color: colorScheme.error.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Xoá'),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colorScheme.outline),
          const SizedBox(height: 10),
          if (sdtDangNhap.isNotEmpty) ...[
            _DongLienHe(
              icon: Icons.call_outlined,
              nhanTruoc: 'SĐT ĐN',
              giaTri: sdtDangNhap,
              nhan: 'Gọi ngay',
              nhanIcon: Icons.arrow_forward_rounded,
              onTap: () => _goiNgay(sdtDangNhap),
            ),
            const SizedBox(height: 8),
          ],
          _DongLienHe(
            icon: Icons.phone_forwarded_outlined,
            nhanTruoc: 'SĐT liên hệ',
            giaTri: sdtLienHe.isEmpty ? '--' : sdtLienHe,
            nhan: sdtLienHe.isEmpty ? null : 'Gọi ngay',
            nhanIcon: sdtLienHe.isEmpty ? null : Icons.arrow_forward_rounded,
            onTap: sdtLienHe.isEmpty ? null : () => _goiNgay(sdtLienHe),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DongLienHe(
              icon: Icons.mail_outline_rounded,
              giaTri: email,
              nhanIcon: Icons.copy_rounded,
              onTap: () => _copyEmail(email),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// BADGE DANH MỤC — màu pastel ổn định theo tên danh mục (tái dùng bảng
// màu avatar, giống badge vai trò bên nhân viên).
// ============================================================
class _DanhMucBadge extends StatelessWidget {
  const _DanhMucBadge({required this.ten, required this.bg, required this.fg});

  final String ten;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        ten,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

// ============================================================
// 1 DÒNG LIÊN HỆ (SĐT / email) — icon + [nhãn trước] + giá trị + hành
// động bên phải (nhan/nhanIcon/onTap đều tuỳ chọn).
// ============================================================
class _DongLienHe extends StatelessWidget {
  const _DongLienHe({
    required this.icon,
    required this.giaTri,
    this.nhanTruoc,
    this.nhan,
    this.nhanIcon,
    this.onTap,
  });

  final IconData icon;
  final String giaTri;
  final String? nhanTruoc;
  final String? nhan;
  final IconData? nhanIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coHanhDong = onTap != null && (nhan != null || nhanIcon != null);
    return Row(
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        if (nhanTruoc != null) ...[
          Text(
            '$nhanTruoc: ',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
        Expanded(
          child: Text(
            giaTri,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (coHanhDong)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nhan != null) ...[
                    Text(
                      nhan!,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (nhanIcon != null)
                    Icon(nhanIcon, size: 15, color: AppColors.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
