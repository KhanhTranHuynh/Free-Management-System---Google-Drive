import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../apis/services/vai_tro_api.dart';
import '../../stores/auth_store.dart';

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

  // ----- options filter "Vai trò" (nạp 1 lần)
  // Lọc bỏ ngay từ nguồn các bản ghi thiếu ma_vai_tro để không bao giờ
  // sinh ra 1 DropdownMenuItem trùng value:null với mục "Tất cả vai trò".
  List<Map<String, dynamic>> _vaiTroOptions = [];
  bool _vaiTroLoading = false;

  int get _tongSo => (_phanTrang['tong_so'] as num?)?.toInt() ?? 0;
  int get _tongTrang => _tongSo <= 0 ? 1 : (_tongSo / _soLuong).ceil();

  String? get _sapXep =>
      _sortColumn == null ? null : '$_sortColumn:${_sortType.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _taiVaiTro();
    _taiLai();
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

  Future<void> _taiVaiTro() async {
    setState(() => _vaiTroLoading = true);
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
  void reload() => _taiLai();

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _timKiem = value.trim();
        _trang = 1;
      });
      _taiLai();
    });
  }

  void _onFilterVaiTroChanged(String? value) {
    setState(() {
      _filterVaiTro = value;
      _trang = 1;
    });
    _taiLai();
  }

  void _onFilterTrangThaiChanged(bool? value) {
    setState(() {
      _filterTrangThai = value;
      _trang = 1;
    });
    _taiLai();
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
    _taiLai();
  }

  void _goToPage(int trang) {
    if (trang < 1 || trang > _tongTrang || trang == _trang) return;
    setState(() => _trang = trang);
    _taiLai();
  }

  /// Rule nghiệp vụ gốc (giữ NGUYÊN như bản JSX):
  /// `"chu_studio".includes(rowData.vai_tro)` — kiểm tra chuỗi cố định
  /// "chu_studio" có CHỨA vai_tro của dòng, không phải ngược lại. Khả năng
  /// là bug gốc (đúng ra nên so sánh `== "chu_studio"`), port y nguyên để
  /// không đổi hành vi hiện tại.
  bool _laChuStudio(Map<String, dynamic> item) =>
      'chu_studio'.contains(item['vai_tro']?.toString() ?? '');

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
                        hintText: 'Tìm kiếm theo tên, số điện thoại...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (coQuyenThem) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: mở AddNhanVienModal thật; gọi reload() sau
                        // khi tạo thành công.
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm nhân viên'),
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
      initialValue: currentValue,
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

          // Cột "Thao tác" chỉ hiện khi có quyền sửa, và không hiện cho chủ
          // studio (giữ nguyên rule gốc).
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
