import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// API bình luận trên ảnh. Khớp src/api/descriptors/binhLuanAnh.js.
class BinhLuanAnhApi {
  BinhLuanAnhApi(this._manager);

  final ApiRequestManager _manager;

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) return List<Map<String, dynamic>>.from(data);
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> binhLuanTheoTepAnh({
    required String idTepAnh,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/binh-luan-anh/theo-tep-anh',
        method: 'GET',
        key: 'binh-luan-theo-tep-anh-$idTepAnh',
        params: {'tep_anh_id': idTepAnh},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được bình luận.');
    }
    return _unwrapList(kq.payload);
  }

  Future<List<Map<String, dynamic>>> binhLuanTheoAlbum({
    required String idAlbum,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/binh-luan-anh/theo-album',
        method: 'POST',
        key: 'binh-luan-theo-album-$idAlbum',
        data: {'id_album': idAlbum},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được bình luận.');
    }
    return _unwrapList(kq.payload);
  }

  Future<void> taoBinhLuan({
    required String idTepAnh,
    required String noiDung,
    String? binhLuanChaId,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/binh-luan-anh/tao',
        method: 'POST',
        key: 'binh-luan-tao',
        data: {
          'tep_anh_id': idTepAnh,
          'noi_dung': noiDung,
          if (binhLuanChaId != null) 'binh_luan_cha_id': binhLuanChaId,
        },
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Gửi bình luận thất bại.');
    }
  }

  Future<void> xoaBinhLuan({required String idBinhLuan}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/binh-luan-anh/xoa',
        method: 'POST',
        key: 'binh-luan-xoa',
        data: {'id_binh_luan_anh': idBinhLuan},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Xoá bình luận thất bại.');
    }
  }

  /// Đánh dấu đã xử lý — CHỈ nhân viên (chủ/thợ chụp/editor) có quyền
  /// giai_quyet — POST /nhan-vien/binh-luan-anh/giai-quyet.
  Future<void> giaiQuyet({
    required String idBinhLuan,
    required bool daGiaiQuyet,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/nhan-vien/binh-luan-anh/giai-quyet',
        method: 'POST',
        key: 'binh-luan-giai-quyet',
        data: {'id_binh_luan_anh': idBinhLuan, 'da_giai_quyet': daGiaiQuyet},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Cập nhật thất bại.');
    }
  }
}
