import 'dart:async';

import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhat_ky_he_thong_api.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart /
// app_spacing.dart trong dự án.
import '../../configs/app_colors.dart';
import '../../configs/app_spacing.dart';
import '../../utils/avatar_util.dart';
import '../../utils/hanh_dong_util.dart';
import '../../utils/time_util.dart';
import '../../components/o_tim_kiem.dart';
import '../../components/chip_loc.dart';
import '../../components/empty_state.dart';
import '../../components/error_retry.dart';

/// Danh sách nhật ký hệ thống. Read-only: không sort (BE cố định
/// ORDER BY created_at DESC), lọc theo hành động qua API + tìm kiếm
/// nhanh phía client trên danh sách đã tải + phân trang kiểu cuộn vô
/// hạn (infinite scroll — cuộn gần cuối tự gọi thêm trang kế tiếp).
///
/// Không đọc quyền AuthStore vì module này không có màn khác gate
/// quyền (route "/nhat-ky-he-thong" tự chặn ở tầng khác nếu cần).
///
/// FIX (chống phân mảnh): file `nhat_ky_he_thong_util.dart` cũ đã bị
/// XOÁ — toàn bộ nội dung của nó (avatar theo tên, màu/icon/nhãn theo
/// hành động) trùng lặp gần như 100% với `tong_quan_util.dart` và
/// component `_ChipLoc` bên dưới cũng trùng với `components/chip_loc.dart`
/// đã có sẵn trong project. Giờ view này import trực tiếp 2 file dùng
/// chung `avatar_util.dart` / `hanh_dong_util.dart` và dùng lại
/// `ChipLoc` thay vì tự định nghĩa lại.
class NhatKyHeThongListView extends StatefulWidget {
  const NhatKyHeThongListView({super.key});

  @override
  State<NhatKyHeThongListView> createState() => _NhatKyHeThongListViewState();
}

class _NhatKyHeThongListViewState extends State<NhatKyHeThongListView> {
  // Kích thước trang nhỏ hơn bản cũ (100) vì giờ tải thêm liên tục theo
  // cuộn thay vì nút chuyển trang — 20 dòng/lần là đủ mượt.
  static const int _soLuong = 20;

  // Bỏ chip "Xoá" theo yêu cầu — hành động 'xoa' vẫn được xử lý bình
  // thường ở icon/màu/badge từng dòng, chỉ không hiện chip lọc riêng.
  static const List<(String?, String)> _hanhDongOptions = [
    (null, 'Tất cả'),
    ('chot_tat_ca_theo_album', 'Chốt album'),
    ('tao', 'Tạo mới'),
    ('cap_nhat', 'Cập nhật'),
  ];

  final _api = NhatKyHeThongApi(ApiRequestManager.instance);
  final _scrollController = ScrollController();
  final _timKiemController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _phanTrang = const {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _requestId = 0;

  String? _filterHanhDong;
  int _trang = 1;

  // Số liệu cho các chip lọc — chỉ chắc chắn đúng khi lấy từ lần tải
  // KHÔNG lọc (filter = null), vì lúc đó danh sách trả về mới bao quát
  // đủ mọi hành động để đếm. Khi đang lọc theo 1 hành động, 2 biến này
  // giữ nguyên giá trị đã cache từ lần tải "Tất cả" gần nhất.
  // TODO: nếu BE có endpoint/field đếm tổng theo hành động (giống
  // so_luong_album_theo_trang_thai bên dashboard), đọc trực tiếp từ đó
  // sẽ chính xác hơn cách suy ra từ trang dữ liệu đầu tiên ở dưới.
  int _tongSoTatCa = 0;
  Map<String, int> _demTheoHanhDong = {};

  int get _tongSo => (_phanTrang['tong_so'] as num?)?.toInt() ?? 0;
  int get _tongTrang => _tongSo <= 0 ? 1 : (_tongSo / _soLuong).ceil();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_taiLaiTuDau());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _timKiemController.dispose();
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

  /// Cập nhật số liệu cho các chip lọc, chỉ khi request vừa rồi KHÔNG
  /// lọc theo hành động cụ thể (xem giải thích ở khai báo 2 biến trên).
  void _capNhatDemChip(
      Map<String, dynamic> body, List<Map<String, dynamic>> itemsTrangDau) {
    if (_filterHanhDong != null) return;

    _tongSoTatCa =
        (_readPage(body)['tong_so'] as num?)?.toInt() ?? itemsTrangDau.length;

    final tuBe = body['so_luong_theo_hanh_dong'];
    if (tuBe is Map) {
      _demTheoHanhDong =
          tuBe.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
      return;
    }

    // BE chưa có sẵn số đếm tổng hợp -> suy ra tạm từ trang dữ liệu vừa
    // tải (chỉ chính xác nếu tổng số bản ghi không vượt quá _soLuong).
    final dem = <String, int>{};
    for (final item in itemsTrangDau) {
      final key = item['hanh_dong']?.toString() ?? '';
      dem[key] = (dem[key] ?? 0) + 1;
    }
    _demTheoHanhDong = dem;
  }

  /// Tải lại từ đầu (trang 1, thay thế toàn bộ danh sách) — dùng khi mở
  /// màn, đổi bộ lọc hành động, kéo-để-làm-mới hoặc bấm nút làm mới.
  Future<void> _taiLaiTuDau() async {
    final id = ++_requestId;
    _trang = 1;

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
      if (!mounted || id != _requestId) return;

      final items = _readList(body);
      final phanTrang = _readPage(body);
      _capNhatDemChip(body, items);

      setState(() {
        _items = items;
        _phanTrang = phanTrang;
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

  /// Tải thêm trang kế tiếp và nối vào cuối danh sách hiện có — được
  /// gọi tự động khi cuộn gần chạm đáy (xem _onScroll).
  Future<void> _taiThem() async {
    if (_isLoadingMore || _isLoading) return;
    if (_trang >= _tongTrang) return;

    final id = ++_requestId;
    final trangMoi = _trang + 1;

    setState(() => _isLoadingMore = true);

    try {
      final body = await _api.layDanhSach(
        trang: trangMoi,
        soLuong: _soLuong,
        hanhDong: _filterHanhDong,
      );
      if (!mounted || id != _requestId) return;

      final themItems = _readList(body);
      final phanTrang = _readPage(body);

      setState(() {
        _items = [..._items, ...themItems];
        _phanTrang = phanTrang;
        _trang = trangMoi;
        _isLoadingMore = false;
      });
    } catch (_) {
      // Lỗi khi tải thêm chỉ âm thầm dừng loading, không đổi thành lỗi
      // toàn màn — người dùng vẫn xem được danh sách đã tải, có thể kéo
      // xuống cuối lần nữa hoặc kéo-làm-mới để thử lại.
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final vitri = _scrollController.position;
    const nguongConLai = 300.0; // px còn lại tới đáy thì bắt đầu tải thêm
    if (vitri.pixels >= vitri.maxScrollExtent - nguongConLai) {
      unawaited(_taiThem());
    }
  }

  void _onFilterHanhDongChanged(String? value) {
    if (value == _filterHanhDong) return;
    setState(() => _filterHanhDong = value);
    unawaited(_taiLaiTuDau());
  }

  // ============================================================
  // Tìm kiếm — lọc phía client trên danh sách ĐÃ TẢI (không gọi thêm
  // API mỗi lần gõ phím). Vì vậy chỉ tìm được trong các trang đã cuộn
  // tới; cuộn thêm để tải nhiều hơn thì phạm vi tìm cũng rộng thêm.
  // TODO: nếu NhatKyHeThongApi.layDanhSach() có hỗ trợ tham số tìm kiếm
  // phía server, nên chuyển qua gọi API để tìm được trên toàn bộ dữ
  // liệu thay vì chỉ phần đã tải.
  // ============================================================
  List<Map<String, dynamic>> get _danhSachHienThi {
    final tuKhoa = _timKiemController.text.trim().toLowerCase();
    if (tuKhoa.isEmpty) return _items;
    return _items.where((item) {
      final hanhDong = (item['hanh_dong_hien_thi'] ??
              hanhDongTieuDe[item['hanh_dong']] ??
              '')
          .toString()
          .toLowerCase();
      final nguoiThucHien =
          (item['nguoi_thuc_hien_ho_ten'] ?? '').toString().toLowerCase();
      return hanhDong.contains(tuKhoa) || nguoiThucHien.contains(tuKhoa);
    }).toList();
  }

  /// Trộn header nhóm ngày (String) xen giữa các dòng log (Map) thành
  /// 1 danh sách phẳng để đổ thẳng vào ListView.builder.
  List<Object> _xayDungRows(List<Map<String, dynamic>> items) {
    final rows = <Object>[];
    String? nhomHienTai;
    for (final item in items) {
      final dt = DateTime.tryParse(item['created_at']?.toString() ?? '');
      final nhom = dt != null ? nhomNgay(dt) : 'Khác';
      if (nhom != nhomHienTai) {
        rows.add(nhom);
        nhomHienTai = nhom;
      }
      rows.add(item);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      // top: false — màn này thường được nhúng bên trong 1 Scaffold/route
      // đã có AppBar hoặc SafeArea riêng lo phần status bar rồi, nên để
      // SafeArea ở đây tự thêm top inset nữa sẽ bị cộng dồn thành khoảng
      // trắng rất to phía trên. Nếu bạn dùng widget này làm MÀN GỐC,
      // không có AppBar/SafeArea nào bọc ngoài, đổi lại thành `top: true`
      // (hoặc bỏ tham số top) để tránh nội dung bị đè lên status bar.
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(tongSo: _tongSoTatCa),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OTimKiem(
                controller: _timKiemController,
                onChanged: (_) => setState(() {}),
                hintText: 'Tìm theo hành động, người thực hiện...',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _hanhDongOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final opt = _hanhDongOptions[index];
                    final key = opt.$1;
                    final dangChon = key == _filterHanhDong;
                    final soDem = key == null
                        ? _tongSoTatCa
                        : (_demTheoHanhDong[key] ?? 0);
                    // FIX: dùng ChipLoc dùng chung (components/chip_loc.dart)
                    // thay vì _ChipLoc riêng của file này — 2 widget này
                    // trước đây gần như giống hệt nhau. soDemDangNgoac:
                    // true để giữ đúng dạng "(5)" như thiết kế gốc của
                    // màn này khi chưa chọn.
                    return ChipLoc(
                      label: opt.$2,
                      soDem: soDem,
                      mau: key == null ? null : hanhDongMau[key],
                      dangChon: dangChon,
                      soDemDangNgoac: true,
                      onTap: () => _onFilterHanhDongChanged(key),
                    );
                  },
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // FIX: dùng ErrorRetry dùng chung thay vì Center(...) viết tay —
    // cùng giao diện với màn Nhân viên.
    if (_error != null && _items.isEmpty) {
      return ErrorRetry(message: _error!, onRetry: _taiLaiTuDau);
    }

    final danhSach = _danhSachHienThi;

    if (danhSach.isEmpty) {
      return const EmptyState(text: 'Không có dữ liệu');
    }

    final rows = _xayDungRows(danhSach);

    return RefreshIndicator(
      onRefresh: _taiLaiTuDau,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: rows.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }

          final row = rows[index];
          if (row is String) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 8),
              child: _NhomNgayHeader(label: row),
            );
          }

          final item = row as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NhatKyTile(item: item),
          );
        },
      ),
    );
  }
}

// ============================================================
// HEADER: chỉ còn tiêu đề + phụ đề, đã bỏ nút back/reload và giảm
// khoảng đệm cho gọn (trước đó bị cao/thừa khoảng trắng phía trên).
// Muốn quay lại hoặc làm mới: dùng gesture back mặc định của hệ điều
// hành / kéo-để-làm-mới (RefreshIndicator) trong phần danh sách.
// ============================================================
class _Header extends StatelessWidget {
  const _Header({required this.tongSo});

  final int tongSo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhật ký hệ thống',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Lịch sử hoạt động và thay đổi ($tongSo bản ghi)',
            style:
                TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER NHÓM NGÀY ("HÔM NAY, 25/9/2026"...)
// ============================================================
class _NhomNgayHeader extends StatelessWidget {
  const _NhomNgayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 1 DÒNG NHẬT KÝ
// ============================================================
class _NhatKyTile extends StatelessWidget {
  const _NhatKyTile({required this.item});

  final Map<String, dynamic> item;

  String _safeValue(String key, String fallback) {
    final v = item[key];
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final hanhDongKey = item['hanh_dong']?.toString() ?? '';
    final mau = hanhDongMau[hanhDongKey] ?? colorScheme.outline;
    // Dùng bộ icon riêng cho danh sách (khác bộ icon timeline bên Tổng
    // quan) — xem giải thích ở đầu hanh_dong_util.dart.
    final icon = hanhDongIconDanhSach[hanhDongKey] ?? Icons.circle_outlined;

    final tieuDe = _safeValue(
        'hanh_dong_hien_thi', hanhDongTieuDe[hanhDongKey] ?? hanhDongKey);
    final theTag =
        _safeValue('ten_bang_hien_thi', item['ten_bang']?.toString() ?? '');
    final nguoiThucHien = item['nguoi_thuc_hien_ho_ten']?.toString() ?? '--';
    // TODO: xác nhận đúng tên field vai trò người thực hiện từ BE (đang
    // giả định 'nguoi_thuc_hien_vai_tro'); nếu khác thì sửa key ở đây.
    final vaiTro = item['nguoi_thuc_hien_vai_tro']?.toString() ?? '';
    final trangThai = _safeValue(
        'trang_thai_hien_thi', trangThaiTheoHanhDong[hanhDongKey] ?? '');

    final avatarIdx = avatarIndex(nguoiThucHien);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: mau),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: mau.withOpacity(0.14),
                              shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Icon(icon, size: 17, color: mau),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                tieuDe,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5),
                              ),
                              if (theTag.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    theTag,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatGio(item['created_at']?.toString()),
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: avatarPalette[avatarIdx],
                          child: Text(
                            layChuCaiDau(nguoiThucHien),
                            style: TextStyle(
                              color: avatarPaletteFg[avatarIdx],
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600),
                              children: [
                                TextSpan(text: nguoiThucHien),
                                if (vaiTro.isNotEmpty)
                                  TextSpan(
                                    text: '  •  $vaiTro',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trangThai.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: mau.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              trangThai,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: mau),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
