import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/danh_muc_khach_hang_api.dart';
import '../../stores/auth_store.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart
// trong dự án (giống nhan_vien_list_view.dart).
import '../../configs/app_colors.dart';
import '../../components/o_tim_kiem.dart';
import '../../components/chip_loc.dart'; // TODO: chỉnh lại đường dẫn cho khớp vị trí thật ChipLoc
import 'add_danh_muc_khach_hang.dart';
import 'edit_danh_muc_khach_hang.dart';

/// Danh sách danh mục khách hàng. State giữ cục bộ trong View vì chỉ
/// phục vụ 1 màn hình; dữ liệu để dạng Map, tự map khi cần.
///
/// UI dạng card theo mẫu thiết kế mới (giống NhanVienListView): mỗi danh
/// mục là 1 card có icon vuông bo góc, chip mã, box mô tả, footer 2 nút
/// Sửa/Xoá — thay cho ListTile trơn trước đây.
///
/// FILTER: thêm hàng chip "Tất cả / Hoạt động / Khóa" ngay dưới ô tìm
/// kiếm, lọc theo field `dang_hoat_dong` — filter được GỬI LÊN API (server
/// side), không lọc lại danh sách ở client, để phân trang vẫn đúng.
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

  // null = Tất cả, true = Hoạt động, false = Khóa.
  bool? _dangHoatDongLoc;

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
      // TODO: xác nhận tên tham số thật trong DanhMucKhachHangApi.layDanhSach
      // — đang giả định `dangHoatDong` (bool?, null = không lọc trạng thái).
      final body = await _api.layDanhSach(
        timKiem: _timKiem,
        trang: 1,
        soLuong: _soLuong,
        dangHoatDong: _dangHoatDongLoc,
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
        dangHoatDong: _dangHoatDongLoc,
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

  /// Đổi chip lọc trạng thái; bỏ qua nếu bấm lại đúng chip đang chọn.
  void _onChonLoc(bool? value) {
    if (_dangHoatDongLoc == value) return;
    setState(() => _dangHoatDongLoc = value);
    _taiLai();
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OTimKiem(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  hintText: 'Tìm kiếm danh mục khách hàng...',
                ),
              ),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChipLoc(
                    label: 'Tất cả',
                    dangChon: _dangHoatDongLoc == null,
                    onTap: () => _onChonLoc(null),
                  ),
                  const SizedBox(width: 8),
                  ChipLoc(
                    label: 'Hoạt động',
                    mau: const Color(0xFF16A34A),
                    dangChon: _dangHoatDongLoc == true,
                    onTap: () => _onChonLoc(true),
                  ),
                  const SizedBox(width: 8),
                  ChipLoc(
                    label: 'Khóa',
                    mau: const Color(0xFF9CA3AF),
                    dangChon: _dangHoatDongLoc == false,
                    onTap: () => _onChonLoc(false),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
      return Center(
        child: Text(
          _dangHoatDongLoc == null
              ? 'Chưa có danh mục khách hàng nào'
              : _dangHoatDongLoc == true
                  ? 'Chưa có danh mục đang hoạt động'
                  : 'Chưa có danh mục bị khóa',
        ),
      );
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
            child: _DanhMucCard(
              item: item,
              coQuyenSua: coQuyenSua,
              coQuyenXoa: coQuyenXoa,
              onSua: () => _moModalSua(item),
              onXoa: () => _xacNhanXoa(item),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// CARD 1 DANH MỤC KHÁCH HÀNG — khớp mẫu: icon vuông bo góc + tên + badge
// trạng thái, chip "Mã:", box mô tả, footer 2 nút Sửa/Xoá.
// ============================================================
class _DanhMucCard extends StatelessWidget {
  const _DanhMucCard({
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

  Color _parseColor(String? hex, {required Color fallback}) {
    if (hex == null) return fallback;
    final clean = hex.replaceAll('#', '');
    final value =
        int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return value == null ? fallback : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final ten = item['ten_hien_thi']?.toString() ?? '';
    final ma = item['ma_danh_muc']?.toString() ?? '';
    final moTa = item['mo_ta']?.toString() ?? '';
    final hoatDong = item['dang_hoat_dong'] == true;

    final iconBg = _parseColor(item['mau_sac']?.toString(),
        fallback: const Color(0xFFFFE9B8));

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFB8874A)),
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
                            ten,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(hoatDong: hoatDong),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Mã: ',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurfaceVariant)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ma,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (coQuyenSua) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onSua,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Sửa'),
                ),
              ],
              if (coQuyenXoa) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onXoa,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Xoá'),
                ),
              ],
            ],
          ),
          if (moTa.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'MÔ TẢ DANH MỤC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(moTa, style: const TextStyle(fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.hoatDong});

  final bool hoatDong;

  @override
  Widget build(BuildContext context) {
    final color = hoatDong ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            hoatDong ? 'Hoạt động' : 'Khóa',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
