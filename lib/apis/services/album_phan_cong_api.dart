import '../api_request_manager.dart';
import '../models/api_exception.dart';

class AlbumPhanCongApi {
  AlbumPhanCongApi(this._manager);

  final ApiRequestManager _manager;

  Map<String, dynamic> _boLopData(dynamic kq, String defaultLoi) {
    if (!kq.isSuccess) {
      throw kq.error ?? ApiException(message: defaultLoi);
    }
    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
  }

  /// Danh sách người đang phụ trách 1 album.
  /// POST /album/phan-cong/danh-sach
  Future<List<Map<String, dynamic>>> danhSach({
    required String idAlbum,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/danh-sach',
        method: 'POST',
        key: 'album-phan-cong-danh-sach',
        data: {'id_album': idAlbum},
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách phụ trách.');
    }

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is List) return List<Map<String, dynamic>>.from(inner);
      if (inner is Map) {
        final list = inner['du_lieu'] ?? inner['items'];
        if (list is List) return List<Map<String, dynamic>>.from(list);
      }
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return const [];
  }

  /// Lịch phân công (nếu màn hình khác cần xem dạng lịch/calendar).
  /// POST /album/phan-cong/lich
  Future<Map<String, dynamic>> lich(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/lich',
        method: 'POST',
        key: 'album-phan-cong-lich',
        data: payload,
      ),
    );
    return _boLopData(kq, 'Không tải được lịch phân công.');
  }

  /// Gán 1 nhân viên phụ trách album.
  /// POST /album/phan-cong — quyền LICH_PHAN_CONG.them
  Future<Map<String, dynamic>> ganPhuTrach({
    required String idAlbum,
    required String taiKhoanNhanVienId,
    String? vaiTroPhuTrach,
    bool? laNguoiBaoCao,
    String? thoiGianBatDau,
    String? thoiGianKetThuc,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong',
        method: 'POST',
        key: 'album-phan-cong',
        data: {
          'id_album': idAlbum,
          'tai_khoan_nhan_vien_id': taiKhoanNhanVienId,
          'vai_tro_phu_trach': vaiTroPhuTrach,
          if (laNguoiBaoCao == true) 'la_nguoi_bao_cao': true,
          'thoi_gian_bat_dau': thoiGianBatDau,
          'thoi_gian_ket_thuc': thoiGianKetThuc,
        },
      ),
    );
    return _boLopData(kq, 'Phân công thất bại.');
  }

  /// Huỷ phân công 1 người khỏi album.
  /// POST /album/phan-cong/xoa — quyền LICH_PHAN_CONG.xoa
  Future<Map<String, dynamic>> huyPhuTrach({
    required String idAlbum,
    required String idAlbumPhuTrach,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/xoa',
        method: 'POST',
        key: 'album-huy-phan-cong',
        data: {
          'id_album': idAlbum,
          'id_album_phu_trach': idAlbumPhuTrach,
        },
      ),
    );
    return _boLopData(kq, 'Huỷ phân công thất bại.');
  }

  /// Đổi người báo cáo chính của album.
  /// POST /album/phan-cong/doi-nguoi-bao-cao — quyền LICH_PHAN_CONG.sua
  Future<Map<String, dynamic>> doiNguoiBaoCao({
    required String idAlbum,
    required String idAlbumPhuTrach,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/doi-nguoi-bao-cao',
        method: 'POST',
        key: 'album-doi-nguoi-bao-cao',
        data: {
          'id_album': idAlbum,
          'id_album_phu_trach': idAlbumPhuTrach,
        },
      ),
    );
    return _boLopData(kq, 'Đổi người báo cáo thất bại.');
  }
}
