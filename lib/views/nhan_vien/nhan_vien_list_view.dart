import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../apis/services/vai_tro_api.dart';
import '../../stores/auth_store.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án.
import '../../configs/app_colors.dart';
import '../../utils/avatar_util.dart';
import '../../components/app_modal.dart';
import '../../components/o_tim_kiem.dart';
import '../../components/chip_loc.dart';
import '../../components/empty_state.dart';
import '../../components/error_retry.dart';
import '../../components/status_indicator.dart';
import 'add_nhan_vien.dart';
import 'edit_nhan_vien.dart';

// ============================================================
// 1 DÒNG "SẮP XẾP THEO" trong modal Lọc & sắp xếp — bấm để chọn cột sắp
// xếp; nếu đang chọn cột này rồi thì hiện icon mũi tên theo chiều hiện
// tại (tăng dần ↑ / giảm dần ↓). Bấm lại cột đang chọn sẽ đảo chiều (xử
// lý ở _onSortColumnTap, widget này chỉ hiển thị).
// ============================================================
class _DongSapXep extends StatelessWidget {
  const _DongSapXep({
    required this.label,
    required this.dangChon,
    required this.tangDan,
    required this.onTap,
  });

  final String label;
  final bool dangChon;
  final bool tangDan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              dangChon
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color:
                  dangChon ? AppColors.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: dangChon ? FontWeight.w700 : FontWeight.w500,
                  color: dangChon
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (dangChon)
              Icon(
                tangDan
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Danh sách nhân viên. Toàn bộ state (search/filter/sort/phân trang) +
/// gọi API nằm cục bộ trong View này — AuthStore chỉ được đọc để lấy quyền
/// (NHAN_VIEN: xem/thêm/sửa) và id_studio_local, không có store riêng cho
/// màn hình này. Dữ liệu để dạng Map thô, đọc field trực tiếp khi cần.
///
/// UI dạng card theo mẫu thiết kế mới. Có 2 chiều lọc (vai trò + trạng
/// thái) — mẫu gốc chỉ vẽ 1 hàng chip theo vai trò nên hàng trạng thái
/// được thêm thêm bên dưới, nhỏ và nhạt hơn để không lấn vai trò chính.
class NhanVienListView extends StatefulWidget {
  const NhanVienListView({super.key});

  @override
  State<NhanVienListView> createState() => _NhanVienListViewState();
}

class _NhanVienListViewState extends State<NhanVienListView> {
  static const int _soLuong = 10;

  /// Các cột cho phép sắp xếp (khớp bản React: chỉ tên / SĐT / email).
  static const List<(String, String)> _cotSapXep = [
    ('ho_ten', 'Tên nhân viên'),
    ('so_dien_thoai', 'Số điện thoại'),
    ('email', 'Email'),
  ];

  /// Chip lọc trạng thái — cố định 3 lựa chọn, không cần nạp từ API.
  static const List<(bool?, String, Color?)> _trangThaiOptions = [
    (null, 'Tất cả trạng thái', null),
    (true, 'Hoạt động', Color(0xFF16A34A)),
    (false, 'Khóa', Color(0xFF9CA3AF)),
  ];

  final _api = NhanVienApi(ApiRequestManager.instance);
  final _vaiTroApi = VaiTroApi(ApiRequestManager.instance);
  final _searchController = TextEditingController();
  Timer? _debounce;

  // ----- danh sách chính
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _phanTrang = const {};
  bool _isLoading = false;
  String? _error;
  int _requestId = 0; // bỏ kết quả cũ khi search/filter/sort đổi liên tục

  // ----- search / filter / sort (giữ nguyên logic từ bản React)
  String _timKiem = '';
  String? _filterVaiTro; // ma_vai_tro đang chọn, null = tất cả
  bool? _filterTrangThai; // null = tất cả, true = hoạt động, false = khóa
  int _trang = 1; // 1-based, khớp param BE
  String? _sortColumn; // vd "ho_ten"
  String _sortType = 'ASC'; // "ASC" | "DESC"

  // ----- options filter "Vai trò" (nạp 1 lần, dùng lại cho modal thêm/sửa
  // và cho hàng chip lọc theo vai trò).
  // Lọc bỏ ngay từ nguồn các bản ghi thiếu ma_vai_tro để không bao giờ
  // sinh ra 1 chip trùng giá trị null với chip "Tất cả".
  List<Map<String, dynamic>> _vaiTroOptions = [];
  bool _vaiTroLoading = false;
  Future<void>? _vaiTroFuture; // chống gọi trùng khi đang tải

  bool _dangMoModal = false; // chặn bấm "Thêm"/"Sửa" nhiều lần cùng lúc

  // Số liệu cho header phụ đề & các chip lọc — chỉ chắc chắn đúng khi lấy
  // từ lần tải KHÔNG lọc gì cả (cả vai trò lẫn trạng thái đều null), vì
  // lúc đó trang dữ liệu đầu mới bao quát đủ để suy luận. Khi đang lọc,
  // các biến này giữ nguyên giá trị đã cache từ lần tải "Tất cả" gần nhất.
  // TODO: nếu BE có endpoint/field đếm tổng theo vai trò & trạng thái
  // (giống so_luong_theo_hanh_dong bên Nhật ký hệ thống), nên đọc trực
  // tiếp từ đó — cách suy ra ở dưới chỉ đúng khi tổng số nhân viên không
  // vượt quá kích thước 1 trang (_soLuong).
  int _tongSoTatCa = 0;
  int _soLuongHoatDong = 0;
  Map<String, int> _demTheoVaiTro = {};

  int get _tongSo => (_phanTrang['tong_so'] as num?)?.toInt() ?? 0;
  int get _tongTrang => _tongSo <= 0 ? 1 : (_tongSo / _soLuong).ceil();

  String? get _sapXep =>
      _sortColumn == null ? null : '$_sortColumn:${_sortType.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    unawaited(_taiVaiTro());
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

  /// Nạp danh sách vai trò. Nếu đang tải dở thì dùng lại Future cũ.
  Future<void> _taiVaiTro() {
    return _vaiTroFuture ??=
        _fetchVaiTro().whenComplete(() => _vaiTroFuture = null);
  }

  Future<void> _fetchVaiTro() async {
    if (mounted) setState(() => _vaiTroLoading = true);
    try {
      final body = await _vaiTroApi.layDanhSach(
        trang: 1,
        soLuong: 100,
        trangThai: true,
      );
      if (!mounted) return;
      setState(() {
        // Bỏ các bản ghi không có ma_vai_tro để tránh sinh chip trùng
        // giá trị null với chip "Tất cả".
        _vaiTroOptions =
            _readList(body).where((vt) => vt['ma_vai_tro'] != null).toList();
        _vaiTroLoading = false;
      });
      // FIX: log cảnh báo nếu API trả về 200 nhưng danh sách rỗng (vd BE
      // đổi tên field khác 'du_lieu', hoặc 'phan_trang' khác cấu trúc
      // mong đợi) — trước đây trường hợp này im lặng hoàn toàn và khiến
      // nút Thêm/Sửa bị chặn ở _dambaoVaiTroDaTai() mà không ai biết vì sao.
      if (_vaiTroOptions.isEmpty) {
        debugPrint(
          '[NhanVien] CANH BAO: _fetchVaiTro tra ve danh sach RONG. '
          'body nhan duoc tu API: $body',
        );
      }
    } catch (e, st) {
      // FIX: log rõ lỗi ra console thay vì nuốt im lặng. Đây là nguyên
      // nhân phổ biến nhất khiến nút "Thêm"/"Sửa" bấm mà không mở gì:
      // _vaiTroOptions luôn rỗng -> _dambaoVaiTroDaTai() chặn từ trước
      // khi kịp gọi showAppModal.
      debugPrint('[NhanVien] LOI khi tai danh sach vai tro: $e\n$st');
      if (!mounted) return;
      setState(() {
        _vaiTroOptions = [];
        _vaiTroLoading = false;
      });
    }
  }

  /// Cập nhật số liệu cho header phụ đề & các chip lọc, chỉ khi request
  /// vừa rồi KHÔNG lọc gì cả (xem giải thích ở khai báo các biến trên).
  void _capNhatDemChip(
      Map<String, dynamic> body, List<Map<String, dynamic>> itemsTrangDau) {
    if (_filterVaiTro != null || _filterTrangThai != null) return;

    _tongSoTatCa =
        (_readPage(body)['tong_so'] as num?)?.toInt() ?? itemsTrangDau.length;
    _soLuongHoatDong =
        itemsTrangDau.where((item) => item['trang_thai'] == true).length;

    final dem = <String, int>{};
    for (final item in itemsTrangDau) {
      final raw = item['vai_tro'];
      final codes = raw is List
          ? raw.map((e) => e.toString())
          : (raw == null ? const <String>[] : [raw.toString()]);
      for (final code in codes) {
        dem[code] = (dem[code] ?? 0) + 1;
      }
    }
    _demTheoVaiTro = dem;
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
        vaiTro: _filterVaiTro,
        trangThai: _filterTrangThai,
        sapXep: _sapXep,
      );
      if (!mounted || id != _requestId) return;

      final items = _readList(body);
      _capNhatDemChip(body, items);

      setState(() {
        _items = items;
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

  /// Gọi lại sau khi thêm/sửa/xoá nhân viên thành công (giữ nguyên trang).
  void reload() => unawaited(_taiLai());

  /// Đảm bảo danh sách vai trò đã tải xong trước khi mở modal thêm/sửa
  /// (cả 2 modal nhận bản chụp options, không tự cập nhật sau đó).
  Future<bool> _dambaoVaiTroDaTai() async {
    if (_vaiTroOptions.isEmpty) await _taiVaiTro();
    if (!mounted) return false;
    if (_vaiTroOptions.isEmpty) {
      // FIX: log để biết chính xác lúc nào popup bị chặn tại đây, thay vì
      // chỉ hiện 1 toast dễ bị bỏ sót.
      debugPrint(
        '[NhanVien] Chan mo modal Them/Sua vi danh sach vai tro dang rong.',
      );
      _thongBao('Không tải được danh sách vai trò. Vui lòng thử lại.');
      return false;
    }
    return true;
  }

  /// Mở modal thêm nhân viên.
  Future<void> _moModalThem() async {
    if (_dangMoModal) return;
    _dangMoModal = true;
    try {
      debugPrint('[NhanVien] Bat dau mo modal THEM');
      if (!await _dambaoVaiTroDaTai()) return;

      debugPrint('[NhanVien] Chuan bi goi showAddNhanVienModal');
      final ok = await showAddNhanVienModal(
        context,
        vaiTroOptions: _vaiTroOptions,
      );
      debugPrint('[NhanVien] showAddNhanVienModal tra ve: $ok');
      if (!mounted) return;

      if (ok == true) {
        _thongBao('Thêm nhân viên thành công');
        reload();
      }
    } finally {
      _dangMoModal = false;
    }
  }

  /// Mở modal sửa nhân viên cho [item] đang chọn.
  Future<void> _moModalSua(Map<String, dynamic> item) async {
    if (_dangMoModal) return;
    _dangMoModal = true;
    try {
      debugPrint('[NhanVien] Bat dau mo modal SUA cho item: $item');
      if (!await _dambaoVaiTroDaTai()) return;

      debugPrint('[NhanVien] Chuan bi goi showEditNhanVienModal');
      final ok = await showEditNhanVienModal(
        context,
        nhanVien: item,
        vaiTroOptions: _vaiTroOptions,
      );
      debugPrint('[NhanVien] showEditNhanVienModal tra ve: $ok');
      if (!mounted) return;

      if (ok == true) {
        _thongBao('Cập nhật nhân viên thành công');
        reload();
      }
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

  /// Bấm nút "..." kế bên ô tìm kiếm — mở modal Lọc & sắp xếp.
  Future<void> _moModalLocSapXep() async {
    FocusScope.of(context).unfocus();
    await showAppModal(
      context,
      title: 'Lọc & sắp xếp',
      type: AppModalType.bottomSheet,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void chon(VoidCallback thayDoi) {
            thayDoi();
            setModalState(() {});
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sắp xếp theo',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              for (final col in _cotSapXep)
                _DongSapXep(
                  label: col.$2,
                  dangChon: _sortColumn == col.$1,
                  tangDan: _sortType == 'ASC',
                  onTap: () => chon(() => _onSortColumnTap(col.$1)),
                ),
              const SizedBox(height: 20),
              const Text('Vai trò',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChipLoc(
                    label: 'Tất cả',
                    soDem: _tongSoTatCa,
                    soDemDangNgoac: false,
                    dangChon: _filterVaiTro == null,
                    onTap: () => chon(() => _onFilterVaiTroChanged(null)),
                  ),
                  for (final vt in _vaiTroOptions)
                    ChipLoc(
                      label: vt['ten_hien_thi']?.toString() ??
                          vt['ma_vai_tro']?.toString() ??
                          '',
                      soDem: _demTheoVaiTro[vt['ma_vai_tro']?.toString()] ?? 0,
                      soDemDangNgoac: false,
                      dangChon: _filterVaiTro == vt['ma_vai_tro']?.toString(),
                      onTap: () => chon(() =>
                          _onFilterVaiTroChanged(vt['ma_vai_tro']?.toString())),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Trạng thái',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in _trangThaiOptions)
                    ChipLoc(
                      label: opt.$2,
                      mau: opt.$3,
                      dangChon: _filterTrangThai == opt.$1,
                      onTap: () =>
                          chon(() => _onFilterTrangThaiChanged(opt.$1)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => chon(_xoaLoc),
                      child: const Text('Xoá lọc'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: const Text('Xong'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Xoá toàn bộ lọc + sắp xếp đang áp dụng, quay về mặc định.
  void _xoaLoc() {
    setState(() {
      _filterVaiTro = null;
      _filterTrangThai = null;
      _sortColumn = null;
      _sortType = 'ASC';
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  /// Nhãn tóm tắt bộ lọc/sắp xếp hiện tại — hiện ngay ngoài danh sách
  /// (không hiện lại toàn bộ chip như trước, bấm vào đây cũng mở modal).
  String get _nhanTomTat {
    final vaiTro = _filterVaiTro == null
        ? 'Tất cả vai trò'
        : (_vaiTroOptions
                .firstWhere(
                    (vt) => vt['ma_vai_tro']?.toString() == _filterVaiTro,
                    orElse: () =>
                        {'ten_hien_thi': _filterVaiTro})['ten_hien_thi']
                ?.toString() ??
            _filterVaiTro!);
    final trangThai = _filterTrangThai == null
        ? 'Tất cả trạng thái'
        : (_filterTrangThai! ? 'Hoạt động' : 'Khóa');
    if (_sortColumn == null) return '$vaiTro · $trangThai';
    final col = _cotSapXep.firstWhere((c) => c.$1 == _sortColumn,
        orElse: () => (_sortColumn!, _sortColumn!));
    final mui = _sortType == 'ASC' ? '↑' : '↓';
    return '$vaiTro · $trangThai · Sắp xếp: ${col.$2} $mui';
  }

  void _onFilterVaiTroChanged(String? value) {
    if (value == _filterVaiTro) return;
    setState(() {
      _filterVaiTro = value;
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  void _onFilterTrangThaiChanged(bool? value) {
    if (value == _filterTrangThai) return;
    setState(() {
      _filterTrangThai = value;
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

  /// Không cho sửa chủ studio. `vai_tro` có thể là List (nhiều vai trò) hoặc
  /// String; chỉ coi là chủ studio khi mã vai trò == "chu_studio".
  /// (Bản JSX gốc dùng `"chu_studio".includes(vai_tro)` — với vai_tro rỗng/null
  /// bản port cũ trả về true nên ẩn nút Sửa nhầm; đã sửa cho đúng ý nghiệp vụ.)
  bool _laChuStudio(Map<String, dynamic> item) {
    final raw = item['vai_tro'];
    final Iterable<String> codes = raw is List
        ? raw.map((e) => e.toString())
        : (raw == null ? const <String>[] : [raw.toString()]);
    return codes.contains('chu_studio');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final coQuyenXem = auth.coQuyen('NHAN_VIEN', 'xem');
    final coQuyenThem = auth.coQuyen('NHAN_VIEN', 'them');
    final coQuyenSua = auth.coQuyen('NHAN_VIEN', 'sua');

    if (!coQuyenXem) {
      return const Center(child: Text('Không có quyền xem'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _Header(
            soLuongHoatDong: _soLuongHoatDong,
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
                  hintText: 'Tìm kiếm theo tên, số điện thoại...',
                ),
              ),
              const SizedBox(width: 8),
              _buildNutMoRong(),
            ],
          ),
        ),
        // Tóm tắt lọc + sắp xếp hiện tại (bấm vào cũng mở lại modal) — thay
        // vì hiện hết 2 hàng chip như trước, giờ chỉ hiện đang lọc/sắp xếp
        // theo gì cho gọn, chi tiết đầy đủ nằm trong modal ở nút "...".
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: InkWell(
            onTap: _moModalLocSapXep,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _nhanTomTat,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(coQuyenSua)),
        if (_tongTrang > 1) _buildPagination(),
      ],
    );
  }

  /// Nút "..." kế bên ô tìm kiếm, mở modal Lọc & sắp xếp.
  Widget _buildNutMoRong() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        tooltip: 'Lọc & sắp xếp',
        onPressed: _moModalLocSapXep,
        icon: const Icon(Icons.more_vert_rounded),
      ),
    );
  }

  Widget _buildBody(bool coQuyenSua) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // FIX: dùng ErrorRetry/EmptyState dùng chung thay vì Center(...) viết
    // tay riêng cho màn này — cùng 1 giao diện với Nhật ký hệ thống.
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: _taiLai);
    }

    if (_items.isEmpty) {
      return const EmptyState(text: 'Không có dữ liệu');
    }

    return RefreshIndicator(
      onRefresh: _taiLai,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isOwner = _laChuStudio(item);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NhanVienCard(
              item: item,
              isOwner: isOwner,
              showEdit: coQuyenSua && !isOwner,
              onSua: () => _moModalSua(item),
            ),
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

// ============================================================
// HEADER: tiêu đề + phụ đề (số đang hoạt động) + nút "Thêm Nhân Viên".
// ============================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.soLuongHoatDong,
    required this.coQuyenThem,
    required this.onThem,
  });

  final int soLuongHoatDong;
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
                'Nhân viên',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '$soLuongHoatDong nhân viên đang hoạt động',
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
            label: const Text('Thêm Nhân Viên',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// CARD 1 NHÂN VIÊN
// ============================================================
class _NhanVienCard extends StatelessWidget {
  const _NhanVienCard({
    required this.item,
    required this.isOwner,
    required this.showEdit,
    required this.onSua,
  });

  final Map<String, dynamic> item;
  final bool isOwner;
  final bool showEdit;
  final VoidCallback onSua;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoTen = item['ho_ten']?.toString() ?? '--';
    final soDienThoai = item['so_dien_thoai']?.toString() ?? '--';
    final email = item['email']?.toString() ?? '--';
    final trangThai = item['trang_thai'] == true;
    final avatarIdx = avatarIndex(hoTen);

    final avatarBg = parseHexColor(
      item['mau_sac']?.toString(),
      fallback: avatarPalette[avatarIdx],
    );
    final avatarFg = contrastFg(avatarBg);

    // `vai_tro`/`ten_vai_tro` có thể là List (nhiều vai trò) hoặc String —
    // ghép cặp theo đúng thứ tự BE trả về để lấy tên hiển thị cho từng mã.
    final maVaiTroRaw = item['vai_tro'];
    final tenVaiTroRaw = item['ten_vai_tro'];
    final maVaiTroList = maVaiTroRaw is List
        ? maVaiTroRaw.map((e) => e.toString()).toList()
        : (maVaiTroRaw == null ? const <String>[] : [maVaiTroRaw.toString()]);
    final tenVaiTroList = tenVaiTroRaw is List
        ? tenVaiTroRaw.map((e) => e.toString()).toList()
        : (tenVaiTroRaw == null ? const <String>[] : [tenVaiTroRaw.toString()]);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwner
              ? AppColors.primary.withOpacity(0.4)
              : colorScheme.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
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
                        layChuCaiDau(hoTen),
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  hoTen,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOwner)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text('👑',
                                      style: TextStyle(fontSize: 14)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (var i = 0; i < maVaiTroList.length; i++)
                                _VaiTroBadge(
                                  maVaiTro: maVaiTroList[i],
                                  ten: i < tenVaiTroList.length
                                      ? tenVaiTroList[i]
                                      : maVaiTroList[i],
                                ),
                              // Trước là _TrangThaiDot riêng cho màn này ->
                              // dùng StatusIndicator(filled: false) dùng
                              // chung (cùng widget với badge trạng thái
                              // album ở Tổng quan, chỉ khác filled).
                              StatusIndicator(
                                label: trangThai ? 'Hoạt động' : 'Khóa',
                                color: trangThai
                                    ? AppColors.success
                                    : const Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (showEdit) ...[
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: onSua,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                              color: AppColors.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Sửa'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: colorScheme.outline),
                const SizedBox(height: 10),
                _DongLienHe(
                  icon: Icons.call_outlined,
                  giaTri: soDienThoai,
                  nhan: 'Gọi ngay',
                  nhanIcon: Icons.arrow_forward_rounded,
                  // TODO: cần thêm package url_launcher và gọi
                  // launchUrl(Uri(scheme: 'tel', path: soDienThoai)) để mở
                  // trình quay số thật; hiện tại chỉ báo qua SnackBar.
                  onTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                        content: Text('Chưa hỗ trợ gọi điện trực tiếp'))),
                ),
                const SizedBox(height: 8),
                _DongLienHe(
                  icon: Icons.mail_outline_rounded,
                  giaTri: email,
                  nhanIcon: Icons.copy_rounded,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                          const SnackBar(content: Text('Đã sao chép email')));
                  },
                ),
              ],
            ),
          ),
          // Ruy băng "OWNER" cho chủ studio — cắt theo góc bo của card nhờ
          // clipBehavior: Clip.antiAlias ở Container ngoài cùng.
          if (isOwner)
            Positioned(
              top: 14,
              right: -32,
              child: Transform.rotate(
                angle: 0.785398, // 45 độ
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: AppColors.primary,
                  alignment: Alignment.center,
                  child: const Text(
                    'OWNER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// BADGE VAI TRÒ — chủ studio dùng màu primary đặc; các vai trò khác chọn
// màu pastel ổn định theo mã vai trò (tái dùng bảng màu avatar).
// ============================================================
class _VaiTroBadge extends StatelessWidget {
  const _VaiTroBadge({required this.maVaiTro, required this.ten});

  final String maVaiTro;
  final String ten;

  @override
  Widget build(BuildContext context) {
    final laChuStudio = maVaiTro == 'chu_studio';
    final idx = avatarIndex(maVaiTro);
    final bg = laChuStudio ? AppColors.primary : avatarPalette[idx];
    final fg = laChuStudio ? Colors.white : avatarPaletteFg[idx];
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
// 1 DÒNG LIÊN HỆ (SĐT / email) — icon + giá trị + hành động bên phải.
// ============================================================
class _DongLienHe extends StatelessWidget {
  const _DongLienHe({
    required this.icon,
    required this.giaTri,
    required this.nhanIcon,
    required this.onTap,
    this.nhan,
  });

  final IconData icon;
  final String giaTri;
  final String? nhan;
  final IconData nhanIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            giaTri,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
                Icon(nhanIcon, size: 15, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
