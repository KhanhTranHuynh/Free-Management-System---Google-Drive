import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// API thao tác trên tệp ảnh (không bao gồm phần danh sách theo album —
/// nằm ở AlbumApi.danhSachTepAnh). Khớp src/api/descriptors/tepAnh.js.
class TepAnhApi {
  TepAnhApi(this._manager);

  final ApiRequestManager _manager;

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) return List<Map<String, dynamic>>.from(data);
    }
    return const [];
  }

  /// Chi tiết 1 tệp ảnh — kèm yêu cầu chỉnh sửa (mới nhất trước) và
  /// bình luận (mới nhất trước).
  Future<Map<String, dynamic>> chiTiet({required String idTepAnh}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tep-anh/chi-tiet',
        method: 'POST',
        key: 'tep-anh-chi-tiet-$idTepAnh',
        data: {'id_tep_anh': idTepAnh},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được chi tiết ảnh.');
    }
    return _unwrap(kq.payload);
  }

  /// Trả về { truoc, sau } — phiên bản liền kề (so sánh ảnh gốc/đã sửa).
  Future<Map<String, dynamic>> keBen({required String idTepAnh}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tep-anh/ke-ben',
        method: 'POST',
        key: 'tep-anh-ke-ben-$idTepAnh',
        data: {'id_tep_anh': idTepAnh},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Không tải được dữ liệu.');
    }
    return _unwrap(kq.payload);
  }

  Future<void> chonTepAnh({
    required String idAlbum,
    required List<String> idTepAnh,
    required bool chon,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tep-anh/chon',
        method: 'POST',
        key: 'tep-anh-chon',
        data: {'id_album': idAlbum, 'id_tep_anh': idTepAnh, 'chon': chon},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Cập nhật lựa chọn thất bại.');
    }
  }

  Future<void> chonBoChonTepAnhTatCa({
    required String idAlbum,
    required bool chon,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tep-anh/chon-tat-ca',
        method: 'POST',
        key: 'tep-anh-chon-tat-ca',
        data: {'id_album': idAlbum, 'chon': chon},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Cập nhật lựa chọn thất bại.');
    }
  }

  /// Danh sách ảnh đã chọn — khớp TepAnhApi.daChon (POST /tep-anh/da-chon).
  Future<Map<String, dynamic>> daChon(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tep-anh/da-chon',
        method: 'POST',
        key: 'tep-anh-da-chon',
        data: payload,
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách ảnh đã chọn.');
    }
    return _unwrap(kq.payload);
  }

  /// Lưu nhiều tệp ảnh vào album (upload) — khớp
  /// POST /album/tep-anh/luu-nhieu.
  Future<Map<String, dynamic>> luuNhieu({
    required String idAlbum,
    required List<Map<String, dynamic>> files,
    bool suaAlbum = false,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/tep-anh/luu-nhieu',
        method: 'POST',
        key: 'tep-anh-luu-nhieu-$idAlbum',
        data: {
          'album_id': idAlbum,
          'files': files,
          'sua_album': suaAlbum,
        },
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Lưu ảnh thất bại.');
    }
    return _unwrap(kq.payload);
  }

  /// Ảnh liên quan (cùng nhóm gốc/phiên bản) — khớp
  /// GET /tep-anh/lien-quan/:id_tep_anh.
  Future<List<Map<String, dynamic>>> lienQuan(
      {required String idTepAnh}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tep-anh/lien-quan/$idTepAnh',
        method: 'GET',
        key: 'tep-anh-lien-quan-$idTepAnh',
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được ảnh liên quan.');
    }
    return _unwrapList(kq.payload);
  }

  /// Danh sách ảnh theo album + bộ lọc (dùng cho dropdown/meta bộ lọc,
  /// khác với AlbumApi.danhSachTepAnh là danh sách hiển thị chính) —
  /// khớp POST /album/danh-sach-tep-anh-bo-loc.
  Future<Map<String, dynamic>> danhSachBoLoc(
      Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/danh-sach-tep-anh-bo-loc',
        method: 'POST',
        key:
            'tep-anh-danh-sach-bo-loc-${payload['id_album']}-${payload['trang']}',
        data: payload,
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Không tải được bộ lọc.');
    }
    return _unwrap(kq.payload);
  }

  /// Danh sách ảnh trên Google Drive của album — khớp
  /// POST /album/danh-sach-tep-anh-drive.
  Future<Map<String, dynamic>> danhSachDrive(
      Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/danh-sach-tep-anh-drive',
        method: 'POST',
        key:
            'tep-anh-danh-sach-drive-${payload['id_album']}-${payload['trang']}',
        data: payload,
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách ảnh Drive.');
    }
    return _unwrap(kq.payload);
  }
}
