import 'dart:async';

import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhat_ky_he_thong_api.dart';

/// Danh sách nhật ký hệ thống. Read-only: không search, không sort (BE cố
/// định ORDER BY created_at DESC), chỉ filter theo hành động + phân trang.
/// Không đọc quyền AuthStore vì module này không có màn khác gate quyền
/// (route "/nhat-ky-he-thong" tự chặn ở tầng khác nếu cần — khớp cách
/// TongQuan.jsx không tự check coQuyen cho log).
///
/// TODO(tạm thời): các dòng `print(...)` trong _taiLai() là log debug để
/// xác minh runtime thực tế nếu vẫn còn lỗi hiển thị. Xoá khi đã xác nhận ổn.
class NhatKyHeThongListView extends StatefulWidget {
  const NhatKyHeThongListView({super.key});

  @override
  State<NhatKyHeThongListView> createState() => _NhatKyHeThongListViewState();
}

class _NhatKyHeThongListViewState extends State<NhatKyHeThongListView> {
  static const int _soLuong = 10;

  static const List<(String?, String)> _hanhDongOptions = [
    (null, 'Tất cả hành động'),
    ('tao', 'Tạo mới'),
    ('cap_nhat', 'Cập nhật'),
    ('xoa', 'Xoá'),
  ];

  final _api = NhatKyHeThongApi(ApiRequestManager.instance);

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _phanTrang = const {};
  bool _isLoading = false;
  String? _error;
  int _requestId = 0;

  String? _filterHanhDong;
  int _trang = 1;

  int get _tongSo => (_phanTrang['tong_so'] as num?)?.toInt() ?? 0;
  int get _tongTrang => _tongSo <= 0 ? 1 : (_tongSo / _soLuong).ceil();

  @override
  void initState() {
    super.initState();
    unawaited(_taiLai());
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

  Future<void> _taiLai() async {
    final id = ++_requestId;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final body = await _api.layDanhSach(
        trang: _trang,
        soLuong: _soLuong,
        hanhDong: _filterHanhDong,
      );

      // ignore: avoid_print
      print('[NhatKyHeThongListView] requestId=$id currentId=$_requestId '
          'mounted=$mounted body=$body');

      if (!mounted || id != _requestId) {
        // ignore: avoid_print
        print('[NhatKyHeThongListView] bỏ qua kết quả vì đã bị thay bởi '
            'request mới hơn hoặc widget đã unmount');
        return;
      }

      final items = _readList(body);
      final phanTrang = _readPage(body);

      // ignore: avoid_print
      print('[NhatKyHeThongListView] items.length=${items.length} '
          'phanTrang=$phanTrang');

      setState(() {
        _items = items;
        _phanTrang = phanTrang;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('[NhatKyHeThongListView] ApiException: ${e.message}');
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _items = [];
        _isLoading = false;
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[NhatKyHeThongListView] Unexpected error: $e\n$st');
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _items = [];
        _isLoading = false;
      });
    }
  }

  void _onFilterHanhDongChanged(String? value) {
    setState(() {
      _filterHanhDong = value;
      _trang = 1;
    });
    unawaited(_taiLai());
  }

  void _goToPage(int trang) {
    if (trang < 1 || trang > _tongTrang || trang == _trang) return;
    setState(() => _trang = trang);
    unawaited(_taiLai());
  }

  String _formatThoiGian(String? iso) {
    if (iso == null || iso.isEmpty) return '--';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '--';
    final gio = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    final ngay = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '$gio $ngay';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String?>(
            initialValue: _filterHanhDong,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Hành động',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final opt in _hanhDongOptions)
                DropdownMenuItem(value: opt.$1, child: Text(opt.$2)),
            ],
            onChanged: _onFilterHanhDongChanged,
          ),
        ),
        Expanded(child: _buildBody()),
        if (_tongTrang > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildBody() {
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
          // Ưu tiên dùng text hiển thị BE trả sẵn (ten_bang_hien_thi,
          // hanh_dong_hien_thi), fallback về key gốc nếu BE chưa map được
          // — khớp logic apiHelper.safeValue(...) bên React.
          final chucNang = _safeValue(
            item,
            'ten_bang_hien_thi',
            item['ten_bang']?.toString() ?? '--',
          );
          final hanhDong = _safeValue(
            item,
            'hanh_dong_hien_thi',
            item['hanh_dong']?.toString() ?? '--',
          );
          final nguoiThucHien =
              item['nguoi_thuc_hien_ho_ten']?.toString() ?? '--';

          return ListTile(
            title: Text(chucNang),
            subtitle: Text(
              '$hanhDong · $nguoiThucHien · '
              '${_formatThoiGian(item['created_at']?.toString())}',
            ),
          );
        },
      ),
    );
  }

  String _safeValue(Map<String, dynamic> item, String key, String fallback) {
    final v = item[key];
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
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
