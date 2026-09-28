import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../apis/models/api_exception.dart';
import '../../../apis/services/album_api.dart';
import '../../../apis/services/album_detail_api.dart';
import '../../../apis/services/tep_anh_api.dart';
import '../../../apis/services/trang_thai_album_api.dart';
import '../../../apis/services/yeu_cau_chinh_sua_api.dart';
import 'album_detail_constants.dart';
import '../../../utils/tai_anh_util.dart';

/// Tương ứng phần state + query + mutation của DetailAlbum.jsx.
/// View chỉ lắng nghe controller và gọi hành động.
class AlbumDetailController extends ChangeNotifier {
  AlbumDetailController({
    required this.idAlbum,
    required this.albumApi,
    required this.tepAnhApi,
    required this.ycsApi,
    required this.trangThaiApi,
    required this.extraApi,
    this.onMessage,
  });

  final String idAlbum;
  final AlbumApi albumApi;
  final TepAnhApi tepAnhApi;
  final YeuCauChinhSuaApi ycsApi;
  final TrangThaiAlbumApi trangThaiApi;
  final AlbumDetailApi extraApi;

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
  String timKiem = '';

  /// Meta bộ lọc (trang_thai_anh, version_anh, lan_yeu_cau, lan_chot).
  Map<String, dynamic>? boLocMeta;

  // ----- header -----
  Map<String, dynamic>? album;
  Map<String, dynamic> thongKe = {};
  bool isLoadingHeader = false;
  String? errorHeader;
  List<Map<String, dynamic>> danhSachTrangThai = [];

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
  bool dangTaiAnhVe = false;
  ({int daXong, int tongSo})? tienDoTaiAnhVe;

  // ---------------------------------------------------------------
  // Getter dẫn xuất
  // ---------------------------------------------------------------
  bool get hasMore => anh.length < tongSo;

  List<String> get idTepAnhDaChon => anh
      .where((a) => a['duoc_khach_chon'] == true)
      .map((a) => a['id_tep_anh'].toString())
      .toList();

  /// Số đã chọn toàn album (server), fallback về số đã tải.
  int get soDaChon =>
      (thongKe['tong_hinh_da_chon'] as num?)?.toInt() ?? idTepAnhDaChon.length;

  /// Trạng thái hiện tại của album, tra trong danh sách trạng thái
  /// (giống trangThaiHienTai ở AlbumHeader.jsx).
  Map<String, dynamic>? get trangThaiHienTai {
    final a = album;
    if (a == null) return null;
    for (final t in danhSachTrangThai) {
      final idT = t['id_trang_thai_album'];
      final ma = t['ma_trang_thai'];
      if ((idT != null && idT == a['id_trang_thai_album']) ||
          (ma != null && (ma == a['ma_trang_thai'] || ma == a['trang_thai']))) {
        return t;
      }
    }
    return null;
  }

  /// Album "hoàn thành"/"huỷ" thì khoá chỉnh sửa (albumDaKhoa).
  bool get albumDaKhoa {
    final ma = trangThaiHienTai?['ma_trang_thai'] ??
        album?['ma_trang_thai'] ??
        album?['trang_thai'];
    return ma == 'hoan_thanh' || ma == 'huy';
  }

  /// BottomActionBar hiện ở tab "Tất cả ảnh" và "Đã chỉnh sửa".
  bool get hienBottomBar =>
      activeTab == AlbumTab.anh || activeTab == AlbumTab.daSua;

  /// Ẩn badge trạng thái ở 2 tab yêu cầu.
  bool get anBadgeTrangThai =>
      activeTab == AlbumTab.yeuCau || activeTab == AlbumTab.chotYeuCau;

  Map<String, dynamic> buildBoLoc() {
    final f = <String, dynamic>{};
    if (activeTab == AlbumTab.anh && daChonFilter != 'tat_ca') {
      f['da_chon'] = daChonFilter == 'da_chon';
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
    if (trangThaiAnhFilter != 'tat_ca') {
      f['trang_thai_anh'] = trangThaiAnhFilter;
    }
    if (lanYeuCauFilter != 'tat_ca') {
      f['lan_yeu_cau'] = int.tryParse(lanYeuCauFilter);
    }
    if (lanChotFilter != 'tat_ca') f['lan_chot'] = int.tryParse(lanChotFilter);
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
    await Future.wait(
        [taiHeader(), taiDanhSachAnh(), taiBoLocMeta(), taiTrangThai()]);
  }

  /// useQuery ["trang-thai-album","danh-sach"]: lọc đang hoạt động + sắp xếp
  /// theo thu_tu.
  Future<void> taiTrangThai() async {
    try {
      final body = await trangThaiApi.danhSach(trang: 1, soLuong: 100);
      final ds = List<Map<String, dynamic>>.from(body['du_lieu'] as List? ?? [])
          .where((e) => e['dang_hoat_dong'] == true)
          .toList()
        ..sort((a, b) => ((a['thu_tu'] as num?)?.toInt() ?? 0)
            .compareTo((b['thu_tu'] as num?)?.toInt() ?? 0));
      danhSachTrangThai = ds;
      _notify();
    } catch (_) {}
  }

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

  /// Giống trangThaiOptionsFinal của PhotoFilterBar.jsx: thứ tự cố định
  /// chưa yêu cầu -> đã yêu cầu -> đã chốt, rồi các option còn lại từ meta.
  List<Map<String, String>> get trangThaiOptions {
    const thuTu = ['chua_yeu_cau', 'da_yeu_cau', 'da_chot'];
    const nhanMacDinh = {
      'chua_yeu_cau': 'Chưa yêu cầu',
      'da_yeu_cau': 'Đã yêu cầu',
      'da_chot': 'Đã chốt',
    };
    final meta = _opts('trang_thai_anh');
    final theoValue = {for (final m in meta) m['value']!: m};
    return <Map<String, String>>[
      for (final v in thuTu)
        theoValue[v] ?? {'value': v, 'label': nhanMacDinh[v]!},
      ...meta.where((m) => !thuTu.contains(m['value'])),
    ];
  }

  /// Nếu meta không có version_anh thì suy ra từ danh sách ảnh đã tải.
  List<Map<String, String>> get verAnhOptions {
    final o = _opts('version_anh', zeroLaGoc: true);
    if (o.isNotEmpty) return o;
    final versions = anh
        .map((a) => (a['lan_sua_hien_tai'] as num?)?.toInt() ?? 0)
        .where((v) => v > 0)
        .toSet()
        .toList()
      ..sort();
    return [
      {'value': 'goc', 'label': 'Ảnh gốc'},
      for (final v in versions) {'value': '$v', 'label': 'Sửa lần $v'},
    ];
  }

  List<Map<String, String>> get lanYeuCauOptions {
    final o = _opts('lan_yeu_cau');
    if (o.isNotEmpty) return o;
    final n = (album?['lan_chot_yeu_cau_chinh_sua'] as num?)?.toInt() ?? 0;
    return [
      for (var i = 1; i <= n; i++) {'value': '$i', 'label': 'Lần $i'}
    ];
  }

  List<Map<String, String>> get lanChotOptions => _opts('lan_chot');

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
  /// Khớp handleChangeTab bên React (reset có điều kiện theo tab).
  void doiTab(String tab) {
    if (tab == activeTab) return;
    activeTab = tab;
    timKiem = '';
    verAnhFilter = 'tat_ca';
    if (tab != AlbumTab.anh) {
      daChonFilter = 'tat_ca';
      trangThaiAnhFilter = 'tat_ca';
    }
    lanChotFilter = 'tat_ca';
    if (tab != AlbumTab.yeuCau &&
        tab != AlbumTab.chotYeuCau &&
        tab != AlbumTab.daSua) {
      lanYeuCauFilter = 'tat_ca';
    }
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

  /// key: ver_anh | lan_yeu_cau | lan_chot
  void doiFilter(String key, String v) {
    switch (key) {
      case 'ver_anh':
        verAnhFilter = v;
      case 'lan_yeu_cau':
        lanYeuCauFilter = v;
      case 'lan_chot':
        lanChotFilter = v;
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
      _msg(chonMoi ? 'Đã chọn tất cả ảnh' : 'Đã bỏ chọn tất cả ảnh');
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
      final res = await ycsApi.chotTatCaTheoAlbum(idAlbum: idAlbum);
      final lan = res['lan_chot'] ??
          res['lan_chot_yeu_cau_chinh_sua'] ??
          res['lan_chot_hien_tai'];
      final conLai = res['so_lan_mien_phi_con_lai'];
      var msg = 'Chốt yêu cầu chỉnh sửa';
      if (lan != null) msg += ' lần $lan';
      msg += ' thành công!';
      if (conLai is num) msg += ' Bạn còn lại $conLai lần chỉnh sửa miễn phí.';
      _msg(msg);
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

  /// handleXoaYeuCauMotAnh bên React.
  Future<void> xoaYeuCauMotAnh(Map<String, dynamic> a, AlbumQuyen q) async {
    final id = a['id_tep_anh']?.toString();
    if (id == null || !q.huyYeuCau || a['duoc_phep_huy_yeu_cau'] != true) {
      return;
    }
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

  // ---------------------------------------------------------------
  // Tải ảnh drive (handleTaiAnhVe)
  // ---------------------------------------------------------------
  /// phamVi: 'tat_ca' | 'bo_loc'.
  Future<void> taiAnhVe(String phamVi) async {
    if (dangTaiAnhVe) return;
    dangTaiAnhVe = true;
    tienDoTaiAnhVe = null;
    _notify();
    try {
      final ds = await extraApi.danhSachTepAnhDrive({
        'id_album': idAlbum,
        if (phamVi != 'tat_ca') ...buildBoLoc(),
      });
      if (ds.isEmpty) {
        _msg('Không có ảnh để tải');
        return;
      }
      tienDoTaiAnhVe = (daXong: 0, tongSo: ds.length);
      _notify();
      final loi = await TaiAnh.taiNhieuTuDrive(ds, (d, t) {
        tienDoTaiAnhVe = (daXong: d, tongSo: t);
        _notify();
      });
      _msg(loi > 0
          ? 'Bỏ qua $loi ảnh tải lỗi từ Google Drive'
          : 'Đã xử lý ${ds.length} ảnh');
    } on ApiException catch (e) {
      _msg(e.message.isNotEmpty ? e.message : 'Tải ảnh Drive về máy thất bại');
    } catch (_) {
      _msg('Tải ảnh Drive về máy thất bại');
    } finally {
      dangTaiAnhVe = false;
      tienDoTaiAnhVe = null;
      _notify();
    }
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
