import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/danh_muc_khach_hang_api.dart';
import '../../stores/auth_store.dart';
import 'add_danh_muc_khach_hang.dart';
import 'edit_danh_muc_khach_hang.dart';

/// Danh sách danh mục khách hàng. State giữ cục bộ trong View vì chỉ
/// phục vụ 1 màn hình; dữ liệu để dạng Map, tự map khi cần.
class DanhMucKhachHangListView extends StatefulWidget {
  const DanhMucKhachHangListView({super.key});

  @override
  State<DanhMucKhachHangListView> createState() =>
      _DanhMucKhachHangListViewState();
}

class _DanhMucKhachHangListViewState extends State<DanhMucKhachHangListView> {
  static const int _soLuong = 10;

  final _api = DanhMucKhachHangApi(ApiRequestManager.instance);
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _phanTrang = const {};
  String _timKiem = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _requestId = 0; // bỏ kết quả cũ khi gõ tìm kiếm nhanh

  bool _dangXuLy = false; // chặn bấm Thêm/Sửa/Xoá dồn dập cùng lúc

  int get _trang => (_phanTrang['trang'] as num?)?.toInt() ?? 1;
  int get _tongTrang => (_phanTrang['tong_trang'] as num?)?.toInt() ?? 1;
  bool get _conTrangSau => _trang < _tongTrang;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _taiLai();
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

  Future<void> _taiLai() async {
    final id = ++_requestId;
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
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _taiThem() async {
    if (_isLoading || _isLoadingMore || !_conTrangSau) return;
    final id = _requestId;
    setState(() => _isLoadingMore = true);

    try {
      final body = await _api.layDanhSach(
        timKiem: _timKiem,
        trang: _trang + 1,
        soLuong: _soLuong,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _items.addAll(_readList(body));
        _phanTrang = _readPage(body);
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _timKiem = value.trim();
      _taiLai();
    });
  }

  /// Mở modal thêm danh mục khách hàng; reload danh sách nếu tạo thành công.
  Future<void> _moModalThem() async {
    if (_dangXuLy) return;
    _dangXuLy = true;
    try {
      final ok = await showAddDanhMucKhachHangModal(context);
      if (!mounted) return;
      if (ok == true) {
        _thongBao('Thêm danh mục khách hàng thành công');
        _taiLai();
      }
    } finally {
      _dangXuLy = false;
    }
  }

  /// Mở modal sửa; reload danh sách nếu cập nhật thành công.
  Future<void> _moModalSua(Map<String, dynamic> item) async {
    if (_dangXuLy) return;
    _dangXuLy = true;
    try {
      final ok = await showEditDanhMucKhachHangModal(context, danhMuc: item);
      if (!mounted) return;
      if (ok == true) {
        _thongBao('Cập nhật danh mục thành công');
        _taiLai();
      }
    } finally {
      _dangXuLy = false;
    }
  }

  /// Hỏi xác nhận rồi gọi API xoá; reload nếu thành công.
  Future<void> _xacNhanXoa(Map<String, dynamic> item) async {
    if (_dangXuLy) return;
    final ten = item['ten_hien_thi']?.toString() ?? 'danh mục này';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá danh mục khách hàng'),
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

    _dangXuLy = true;
    try {
      // TODO: xác nhận đúng tên field id thật (đang giả định 'id', fallback
      // 'id_danh_muc_khach_hang') — khớp với payload ở edit_danh_muc_khach_hang.dart.
      final id = item['id'] ?? item['id_danh_muc_khach_hang'];
      await _api.xoa(id);
      if (!mounted) return;
      _thongBao('Đã xoá danh mục khách hàng');
      _taiLai();
    } on ApiException {
      // toast lỗi đã hiển thị ở tầng API
    } catch (_) {
      if (mounted) _thongBao('Xoá danh mục thất bại. Vui lòng thử lại.');
    } finally {
      _dangXuLy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final coQuyenThem = auth.coQuyen('DANH_MUC_KHACH_HANG', 'them');
    final coQuyenSua = auth.coQuyen('DANH_MUC_KHACH_HANG', 'sua');
    final coQuyenXoa = auth.coQuyen('DANH_MUC_KHACH_HANG', 'xoa');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm danh mục khách hàng...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (coQuyenThem) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _moModalThem,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm'),
                ),
              ],
            ],
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
      return const Center(child: Text('Chưa có danh mục khách hàng nào'));
    }

    return RefreshIndicator(
      onRefresh: _taiLai,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return _ItemTile(
            item: item,
            coQuyenSua: coQuyenSua,
            coQuyenXoa: coQuyenXoa,
            onSua: () => _moModalSua(item),
            onXoa: () => _xacNhanXoa(item),
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.coQuyenSua,
    required this.coQuyenXoa,
    required this.onSua,
    required this.onXoa,
  });

  final Map<String, dynamic> item;
  final bool coQuyenSua;
  final bool coQuyenXoa;
  final VoidCallback onSua;
  final VoidCallback onXoa;

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    final clean = hex.replaceAll('#', '');
    final value =
        int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return value == null ? Colors.grey : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final ten = item['ten_hien_thi']?.toString() ?? '';
    final ma = item['ma_danh_muc']?.toString() ?? '';
    final moTa = item['mo_ta']?.toString() ?? '';
    final hoatDong = item['dang_hoat_dong'] == true;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _parseColor(item['mau_sac']?.toString()),
        radius: 14,
      ),
      title: Text(ten),
      subtitle: Text([ma, if (moTa.isNotEmpty) moTa].join(' • ')),
      // Trạng thái + menu Sửa/Xoá (ẩn hẳn menu nếu không có quyền nào).
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hoatDong ? Icons.check_circle : Icons.pause_circle_outline,
            color: hoatDong ? Colors.green : Colors.grey,
          ),
          if (coQuyenSua || coQuyenXoa)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'sua') onSua();
                if (value == 'xoa') onXoa();
              },
              itemBuilder: (context) => [
                if (coQuyenSua)
                  const PopupMenuItem(value: 'sua', child: Text('Sửa')),
                if (coQuyenXoa)
                  const PopupMenuItem(value: 'xoa', child: Text('Xoá')),
              ],
            ),
        ],
      ),
    );
  }
}
