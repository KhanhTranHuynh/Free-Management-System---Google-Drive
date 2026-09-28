import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../apis/models/api_exception.dart';
import '../../../apis/services/album_api.dart';
import '../../../apis/services/tep_anh_api.dart';
import '../../../apis/services/yeu_cau_chinh_sua_api.dart';
import 'album_detail_constants.dart';

/// Tương ứng phần state + query + mutation của DetailAlbum.jsx.
/// View chỉ lắng nghe controller và gọi hành động.
class AlbumDetailController extends ChangeNotifier {
  AlbumDetailController({
    required this.idAlbum,
    required this.albumApi,
    required this.tepAnhApi,
    required this.ycsApi,
    this.onMessage,
  });

  final String idAlbum;
  final AlbumApi albumApi;
  final TepAnhApi tepAnhApi;
  final YeuCauChinhSuaApi ycsApi;

  /// View gán để hiện SnackBar.
  void Function(String message)? onMessage;

  static const _soLuongMoiTrang = 24;
  static const _toiDaMoiLanGui = 50;

  bool _disposed = false;
  Timer? _debounce;

  // ----- tab / filter -----
  String activeTab = AlbumTab.anh;
  String daChonFilter = 'tat_ca';
  String trangThaiAnhFilter = 'tat_ca';
  String verAnhFilter = 'tat_ca'; // tat_ca | goc | <số>
  String lanYeuCauFilter = 'tat_ca';
  String lanChotFilter = 'tat_ca';
  String tienDoFilter = 'tat_ca';
  String timKiem = '';

  /// Meta bộ lọc (trang_thai_anh, version_anh, lan_yeu_cau, lan_chot, tien_do).
  Map<String, dynamic>? boLocMeta;

  // ----- header -----
  Map<String, dynamic>? album;
  Map<String, dynamic> thongKe = {};
  bool isLoadingHeader = false;
  String? errorHeader;

  // ----- danh sách ảnh -----
  List<Map<String, dynamic>> anh = [];
  int _trang = 1;
  int tongSo = 0;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorAnh;
  int _requestId = 0;

  // ----- trạng thái thao tác -----
  final Set<String> dangDoiChon = {};
  bool dangDoiChonTatCa = false;
  bool dangGuiYeuCau = false;
  bool dangHuyYeuCau = false;
  bool dangChotTatCa = false;
  bool dangXoaCungTatCa = false;
  final Set<String> dangXoaYeuCauMotAnh = {};

  // ---------------------------------------------------------------
  // Getter dẫn xuất
  // ---------------------------------------------------------------
  bool get hasMore => anh.length < tongSo;

  /// Ảnh đang được chọn trong danh sách đã tải (tương ứng idTepAnhDaChonHienThi).
  List<String> get idTepAnhDaChon => anh
      .where((a) => a['duoc_khach_chon'] == true)
      .map((a) => a['id_tep_anh'].toString())
      .toList();

  /// Số đã chọn toàn album (server), fallback về số đã tải.
  int get soDaChon =>
      (thongKe['tong_hinh_da_chon'] as num?)?.toInt() ?? idTepAnhDaChon.length;

  /// Album "hoàn thành"/"huỷ" thì khoá chỉnh sửa (tương ứng albumDaKhoa).
  bool get albumDaKhoa {
    final ma = album?['ma_trang_thai'] ?? album?['trang_thai'];
    return ma == 'hoan_thanh' || ma == 'huy';
  }

  /// Tab hiển thị BottomActionBar.
  bool get hienBottomBar =>
      activeTab == AlbumTab.anh || activeTab == AlbumTab.daSua;

  /// Ẩn badge trạng thái ở 2 tab yêu cầu.
  bool get anBadgeTrangThai =>
      activeTab == AlbumTab.yeuCau || activeTab == AlbumTab.chotYeuCau;

  Map<String, dynamic> buildBoLoc() {
    final f = <String, dynamic>{};
    if (activeTab == AlbumTab.anh) {
      if (daChonFilter != 'tat_ca') f['da_chon'] = daChonFilter == 'da_chon';
      if (trangThaiAnhFilter != 'tat_ca') {
        f['trang_thai_anh'] = trangThaiAnhFilter;
      }
    }
    if (activeTab == AlbumTab.yeuCau) {
      f['yeu_cau_chinh_sua'] = 'da_yeu_cau';
      f['trang_thai_anh'] = 'da_yeu_cau';
    }
    if (activeTab == AlbumTab.chotYeuCau) {
      f['yeu_cau_chinh_sua'] = 'da_yeu_cau';
      f['trang_thai_anh'] = 'da_chot';
    }
    if (activeTab == AlbumTab.daSua) f['version_anh'] = 'da_sua';
    if (verAnhFilter == 'goc') {
      f['version_anh'] = 'goc';
    } else if (verAnhFilter != 'tat_ca') {
      f['version_anh'] = int.tryParse(verAnhFilter) ?? verAnhFilter;
    }
    if (lanYeuCauFilter != 'tat_ca') {
      f['lan_yeu_cau'] = int.tryParse(lanYeuCauFilter);
    }
    if (lanChotFilter != 'tat_ca') f['lan_chot'] = int.tryParse(lanChotFilter);
    if (tienDoFilter != 'tat_ca') f['tien_do'] = tienDoFilter;
    final kw = timKiem.trim();
    if (kw.isNotEmpty) {
      f['tu_khoa'] = kw.length > 255 ? kw.substring(0, 255) : kw;
    }
    return f;
  }

  // ---------------------------------------------------------------
  // Tải dữ liệu
  // ---------------------------------------------------------------
  Future<void> khoiTao() async {
    await Future.wait([taiHeader(), taiDanhSachAnh(), taiBoLocMeta()]);
  }

  /// Tương ứng useQuery ["album","tep-anh-bo-loc-meta"] bên React.
  /// React truyền so_luong 100000; ở đây chỉ cần meta nên lấy 1 (nếu meta
  /// phụ thuộc số lượng thì đổi lại).
  Future<void> taiBoLocMeta() async {
    try {
      boLocMeta = await tepAnhApi
          .danhSachBoLoc({'id_album': idAlbum, 'trang': 1, 'so_luong': 1});
      _notify();
    } catch (_) {
      // Không chặn màn hình nếu meta lỗi — filter dùng option mặc định.
    }
  }

  List<Map<String, String>> _opts(String key, {bool zeroLaGoc = false}) {
    final l = boLocMeta?[key];
    if (l is! List) return const [];
    return l
        .whereType<Map>()
        .map((m) => {
              'value': (zeroLaGoc && m['value'] == 0) ? 'goc' : '${m['value']}',
              'label': '${m['label']}',
            })
        .toList();
  }

  List<Map<String, String>> get trangThaiOptions => _opts('trang_thai_anh');
  List<Map<String, String>> get verAnhOptions =>
      _opts('version_anh', zeroLaGoc: true);
  List<Map<String, String>> get lanYeuCauOptions {
    final o = _opts('lan_yeu_cau');
    if (o.isNotEmpty) return o;
    // Fallback như lanYeuCauOptionsFallback bên React.
    final n = (album?['lan_chot_yeu_cau_chinh_sua'] as num?)?.toInt() ?? 0;
    return [
      for (var i = 1; i <= n; i++) {'value': '$i', 'label': 'Lần $i'}
    ];
  }

  List<Map<String, String>> get lanChotOptions => _opts('lan_chot');
  List<Map<String, String>> get tienDoOptions => _opts('tien_do');

  Future<void> taiHeader() async {
    isLoadingHeader = true;
    errorHeader = null;
    _notify();
    try {
      final body = await albumApi.chiTietHeader(idAlbum: idAlbum);
      album = body;
      thongKe = Map<String, dynamic>.from(body['thong_ke'] as Map? ?? {});
    } on ApiException catch (e) {
      errorHeader =
          e.message.isNotEmpty ? e.message : 'Không tải được thông tin album.';
    } catch (_) {
      errorHeader = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
    isLoadingHeader = false;
    _notify();
  }

  Future<void> taiDanhSachAnh({bool append = false}) async {
    final id = ++_requestId;
    final trangCanTai = append ? _trang + 1 : 1;
    if (append) {
      isLoadingMore = true;
    } else {
      isLoading = true;
    }
    errorAnh = null;
    _notify();

    try {
      final body = await albumApi.danhSachTepAnh(
        idAlbum: idAlbum,
        trang: trangCanTai,
        soLuong: _soLuongMoiTrang,
        boLoc: buildBoLoc(),
      );
      if (_disposed || id != _requestId) return;
      final list =
          List<Map<String, dynamic>>.from(body['du_lieu'] as List? ?? []);
      final pt = Map<String, dynamic>.from(body['phan_trang'] as Map? ?? {});
      tongSo = (pt['tong_so'] as num?)?.toInt() ?? list.length;
      // Giả định: BE trả tong_hop kèm danh sách (React: tongHop từ
      // useAnhAlbumPhanTrang). Nếu không có thì giữ thong_ke của header.
      final th = body['tong_hop'];
      if (th is Map) thongKe = {...thongKe, ...Map<String, dynamic>.from(th)};
      anh = append ? [...anh, ...list] : list;
      _trang = trangCanTai;
    } on ApiException catch (e) {
      if (_disposed || id != _requestId) return;
      errorAnh = e.message.isNotEmpty ? e.message : 'Không tải được ảnh.';
      if (!append) {
        anh = [];
        tongSo = 0;
      }
    } catch (_) {
      if (_disposed || id != _requestId) return;
      errorAnh = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
    isLoading = false;
    isLoadingMore = false;
    _notify();
  }

  Future<void> taiThem() async {
    if (isLoading || isLoadingMore || !hasMore || errorAnh != null) return;
    await taiDanhSachAnh(append: true);
  }

  /// Tương ứng lamMoiDuLieuAlbum.
  Future<void> lamMoi() =>
      Future.wait([taiHeader(), taiDanhSachAnh(), taiBoLocMeta()]);

  // ---------------------------------------------------------------
  // Tab / filter
  // ---------------------------------------------------------------
  void doiTab(String tab) {
    if (tab == activeTab) return;
    activeTab = tab;
    trangThaiAnhFilter = 'tat_ca';
    daChonFilter = 'tat_ca';
    verAnhFilter = 'tat_ca';
    lanYeuCauFilter = 'tat_ca';
    lanChotFilter = 'tat_ca';
    tienDoFilter = 'tat_ca';
    timKiem = '';
    _notify();
    unawaited(taiDanhSachAnh());
  }

  void doiDaChonFilter(String v) {
    daChonFilter = v;
    _notify();
    unawaited(taiDanhSachAnh());
  }

  void doiTrangThaiAnhFilter(String v) {
    trangThaiAnhFilter = v;
    _notify();
    unawaited(taiDanhSachAnh());
  }

  /// key: ver_anh | lan_yeu_cau | lan_chot | tien_do
  void doiFilter(String key, String v) {
    switch (key) {
      case 'ver_anh':
        verAnhFilter = v;
      case 'lan_yeu_cau':
        lanYeuCauFilter = v;
      case 'lan_chot':
        lanChotFilter = v;
      case 'tien_do':
        tienDoFilter = v;
      default:
        return;
    }
    _notify();
    unawaited(taiDanhSachAnh());
  }

  void timKiemDebounce(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      timKiem = value;
      _notify();
      unawaited(taiDanhSachAnh());
    });
  }

  // ---------------------------------------------------------------
  // Chọn ảnh
  // ---------------------------------------------------------------
  void _capNhatAnhCucBo(String idTepAnh, Map<String, dynamic> patch) {
    anh = anh
        .map((a) =>
            a['id_tep_anh'].toString() == idTepAnh ? {...a, ...patch} : a)
        .toList();
  }

  Future<void> toggleChonAnh(Map<String, dynamic> a, AlbumQuyen q) async {
    final id = a['id_tep_anh'].toString();
    if (!q.chonAnh || a['duoc_phep_chon'] != true) return;
    if (dangDoiChon.contains(id)) return;
    await doiChonAnh(id, !(a['duoc_khach_chon'] == true));
  }

  Future<void> doiChonAnh(String idTepAnh, bool chonMoi) async {
    dangDoiChon.add(idTepAnh);
    _notify();
    try {
      await tepAnhApi.chonTepAnh(
        idAlbum: idAlbum,
        idTepAnh: [idTepAnh],
        chon: chonMoi,
      );
      _capNhatAnhCucBo(idTepAnh, {'duoc_khach_chon': chonMoi});
      final cu = (thongKe['tong_hinh_da_chon'] as num?)?.toInt() ?? 0;
      thongKe = {
        ...thongKe,
        'tong_hinh_da_chon': (cu + (chonMoi ? 1 : -1)).clamp(0, 1 << 30),
      };
      // Đang lọc theo "đã chọn" thì refetch để ảnh biến mất khỏi list.
      if (activeTab == AlbumTab.anh && daChonFilter != 'tat_ca') {
        dangDoiChon.remove(idTepAnh);
        await taiDanhSachAnh();
        return;
      }
    } catch (_) {
      _msg('Cập nhật lựa chọn thất bại');
    }
    dangDoiChon.remove(idTepAnh);
    _notify();
  }

  Future<void> chonBoChonTatCa(bool chonMoi, AlbumQuyen q) async {
    if (!q.chonAnh || dangDoiChonTatCa) return;
    dangDoiChonTatCa = true;
    _notify();
    try {
      await tepAnhApi.chonBoChonTepAnhTatCa(idAlbum: idAlbum, chon: chonMoi);
      await Future.wait([taiHeader(), taiDanhSachAnh()]);
    } catch (_) {
      _msg('Cập nhật lựa chọn thất bại');
    }
    dangDoiChonTatCa = false;
    _notify();
  }

  // ---------------------------------------------------------------
  // Yêu cầu chỉnh sửa
  // ---------------------------------------------------------------
  Future<bool> guiYeuCauHangLoat(String noiDung, AlbumQuyen q) async {
    final ids = idTepAnhDaChon;
    if (!q.taoYeuCau || dangGuiYeuCau || ids.isEmpty) return false;
    dangGuiYeuCau = true;
    _notify();
    var ok = false;
    try {
      await ycsApi.taoHangLoat(
        idAlbum: idAlbum,
        tepAnhIds: ids.take(_toiDaMoiLanGui).toList(),
        noiDung: noiDung.trim(),
      );
      _msg('Đã gửi yêu cầu chỉnh sửa');
      ok = true;
      await lamMoi();
    } catch (_) {
      _msg('Gửi yêu cầu chỉnh sửa thất bại');
    }
    dangGuiYeuCau = false;
    _notify();
    return ok;
  }

  Future<void> huyYeuCauDaChon(AlbumQuyen q) async {
    final ids = idTepAnhDaChon;
    if (!q.huyYeuCau || dangHuyYeuCau || ids.isEmpty) return;
    dangHuyYeuCau = true;
    _notify();
    try {
      await ycsApi.xoaTheoTepAnh(tepAnhIds: ids.take(_toiDaMoiLanGui).toList());
      _msg('Đã hủy yêu cầu chỉnh sửa');
      await lamMoi();
    } catch (_) {
      _msg('Hủy yêu cầu chỉnh sửa thất bại');
    }
    dangHuyYeuCau = false;
    _notify();
  }

  Future<void> chotTatCaAlbum(AlbumQuyen q) async {
    if (!q.chotTatCa || dangChotTatCa) return;
    dangChotTatCa = true;
    _notify();
    try {
      await ycsApi.chotTatCaTheoAlbum(idAlbum: idAlbum);
      _msg('Chốt tất cả yêu cầu chỉnh sửa thành công');
      await lamMoi();
    } catch (_) {
      _msg('Chốt tất cả yêu cầu chỉnh sửa thất bại');
    }
    dangChotTatCa = false;
    _notify();
  }

  Future<void> xoaCungTatCaAlbum(AlbumQuyen q) async {
    if (!q.xoaCungTatCa || dangXoaCungTatCa) return;
    dangXoaCungTatCa = true;
    _notify();
    try {
      await ycsApi.xoaCungChuaChotTheoAlbum(idAlbum: idAlbum);
      _msg('Đã xóa vĩnh viễn các yêu cầu chỉnh sửa chưa chốt');
      await lamMoi();
    } catch (_) {
      _msg('Xóa tất cả yêu cầu chỉnh sửa thất bại');
    }
    dangXoaCungTatCa = false;
    _notify();
  }

  // ---------------------------------------------------------------
  /// Xoá yêu cầu chưa chốt của 1 ảnh (handleXoaYeuCauMotAnh bên React).
  Future<void> xoaYeuCauMotAnh(Map<String, dynamic> a, AlbumQuyen q) async {
    final id = a['id_tep_anh']?.toString();
    if (id == null || !q.huyYeuCau || a['duoc_phep_huy_yeu_cau'] != true)
      return;
    if (dangXoaYeuCauMotAnh.contains(id)) return;
    dangXoaYeuCauMotAnh.add(id);
    _notify();
    try {
      await ycsApi.xoaChuaChotTheoTepAnh(idTepAnh: id);
      _msg('Đã xóa yêu cầu chỉnh sửa');
      await lamMoi();
    } catch (_) {
      _msg('Xóa yêu cầu chỉnh sửa thất bại');
    }
    dangXoaYeuCauMotAnh.remove(id);
    _notify();
  }

  void _msg(String s) => onMessage?.call(s);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
