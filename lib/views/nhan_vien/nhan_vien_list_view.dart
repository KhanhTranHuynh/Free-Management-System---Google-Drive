import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../apis/services/vai_tro_api.dart';
import '../../stores/auth_store.dart';
import 'add_nhan_vien.dart';

/// Danh sách nhân viên. Toàn bộ state (search/filter/sort/phân trang) +
/// gọi API nằm cục bộ trong View này — AuthStore chỉ được đọc để lấy quyền
/// (NHAN_VIEN: xem/thêm/sửa) và id_studio_local, không có store riêng cho
/// màn hình này. Dữ liệu để dạng Map thô, đọc field trực tiếp khi cần.
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

  // ----- options filter "Vai trò" (nạp 1 lần, dùng lại cho modal thêm)
  // Lọc bỏ ngay từ nguồn các bản ghi thiếu ma_vai_tro để không bao giờ
  // sinh ra 1 DropdownMenuItem trùng value:null với mục "Tất cả vai trò".
  List<Map<String, dynamic>> _vaiTroOptions = [];
  bool _vaiTroLoading = false;
  Future<void>? _vaiTroFuture; // chống gọi trùng khi đang tải

  bool _dangMoModal = false; // chặn bấm "Thêm" nhiều lần

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
        // Bỏ các bản ghi không có ma_vai_tro để tránh sinh
        // DropdownMenuItem(value: null) trùng với mục "Tất cả vai trò".
        _vaiTroOptions =
            _readList(body).where((vt) => vt['ma_vai_tro'] != null).toList();
        _vaiTroLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vaiTroOptions = [];
        _vaiTroLoading = false;
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
        vaiTro: _filterVaiTro,
        trangThai: _filterTrangThai,
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

  /// Gọi lại sau khi thêm/sửa/xoá nhân viên thành công (giữ nguyên trang).
  void reload() => unawaited(_taiLai());

  /// Mở modal thêm nhân viên. Đảm bảo danh sách vai trò đã tải xong trước
  /// khi mở (modal nhận bản chụp options, không tự cập nhật sau đó).
  Future<void> _moModalThem() async {
    if (_dangMoModal) return;
    _dangMoModal = true;
    try {
      if (_vaiTroOptions.isEmpty) await _taiVaiTro();
      if (!mounted) return;

      if (_vaiTroOptions.isEmpty) {
        _thongBao('Không tải được danh sách vai trò. Vui lòng thử lại.');
        return;
      }

      final ok = await showAddNhanVienModal(
        context,
        vaiTroOptions: _vaiTroOptions,
      );
      if (!mounted) return;

      if (ok == true) {
        _thongBao('Thêm nhân viên thành công');
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

  void _onFilterVaiTroChanged(String? value) {
    setState(() {
      _filterVaiTro = value;
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  void _onFilterTrangThaiChanged(bool? value) {
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
                        hintText: 'Tìm theo tên, số điện thoại...',
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
                  Expanded(
                    child: _buildVaiTroDropdown(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<bool?>(
                      initialValue: _filterTrangThai,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Tất cả trạng thái')),
                        DropdownMenuItem(value: true, child: Text('Hoạt động')),
                        DropdownMenuItem(value: false, child: Text('Khóa')),
                      ],
                      onChanged: _onFilterTrangThaiChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(coQuyenSua)),
        if (_tongTrang > 1) _buildPagination(),
      ],
    );
  }

  /// Menu chọn cột sắp xếp; chọn lại cột đang sắp xếp thì đảo ASC/DESC.
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

  /// Dropdown "Vai trò" tách riêng để xử lý trạng thái loading mà KHÔNG
  /// sinh 2 DropdownMenuItem cùng value:null (mục "Tất cả vai trò" +
  /// mục "Đang tải..." trước đây dùng chung value:null, gây
  /// assertion lỗi "There should be exactly one item with ... value: null").
  /// Cách xử lý: chỉ build item list từ "Tất cả vai trò" + các option đã
  /// load được (rỗng khi đang loading), và disable cả dropdown lúc loading.
  Widget _buildVaiTroDropdown() {
    // Nếu giá trị đang chọn không còn nằm trong danh sách hiện có (vd đang
    // loading lại, hoặc option đó vừa bị lọc bỏ), fallback về null để
    // tránh lỗi "value không khớp item nào".
    final validValues = <String?>{
      null,
      ..._vaiTroOptions.map((vt) => vt['ma_vai_tro']?.toString()),
    };
    final currentValue =
        validValues.contains(_filterVaiTro) ? _filterVaiTro : null;

    return DropdownButtonFormField<String?>(
      // key theo số option + giá trị: initialValue chỉ đọc lúc tạo field,
      // đổi key để dropdown dựng lại khi options vừa nạp xong.
      key: ValueKey('vai-tro-${_vaiTroOptions.length}-$currentValue'),
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Vai trò',
        border: const OutlineInputBorder(),
        suffixIcon: _vaiTroLoading
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
        const DropdownMenuItem(
          value: null,
          child: Text('Tất cả vai trò'),
        ),
        for (final vt in _vaiTroOptions)
          DropdownMenuItem(
            value: vt['ma_vai_tro']?.toString(),
            child: Text(vt['ten_hien_thi']?.toString() ?? ''),
          ),
      ],
      onChanged: _vaiTroLoading ? null : _onFilterVaiTroChanged,
    );
  }

  Widget _buildBody(bool coQuyenSua) {
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
          final tenVaiTroRaw = item['ten_vai_tro'];
          final tenVaiTro = tenVaiTroRaw is List
              ? tenVaiTroRaw.map((e) => e.toString()).join(', ')
              : (tenVaiTroRaw?.toString() ?? '--');
          final trangThai = item['trang_thai'] == true;

          // Nút "Sửa" chỉ hiện khi có quyền sửa, và không hiện cho chủ studio.
          final showEdit = coQuyenSua && !_laChuStudio(item);

          return ListTile(
            title: Text(item['ho_ten']?.toString() ?? '--'),
            subtitle: Text(
              '${item['so_dien_thoai']?.toString() ?? '--'} · '
              '${item['email']?.toString() ?? '--'} · '
              '$tenVaiTro · '
              '${trangThai ? 'Hoạt động' : 'Khóa'}',
            ),
            trailing: showEdit
                ? TextButton(
                    onPressed: () {
                      // TODO: mở EditNhanVienModal thật với `item`; gọi
                      // reload() sau khi sửa thành công.
                    },
                    child: const Text('Sửa'),
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
