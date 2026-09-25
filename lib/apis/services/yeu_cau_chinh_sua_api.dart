import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// API yêu cầu chỉnh sửa ảnh. Khớp
/// src/api/descriptors/yeuCauChinhSua.js.
class YeuCauChinhSuaApi {
  YeuCauChinhSuaApi(this._manager);

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

  /// Tạo yêu cầu chỉnh sửa đơn lẻ — POST /yeu-cau-chinh-sua/tao.
  Future<Map<String, dynamic>> tao(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/tao',
        method: 'POST',
        key: 'ycs-tao',
        data: payload,
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Tạo yêu cầu chỉnh sửa thất bại.');
    }
    return _unwrap(kq.payload);
  }

  Future<void> sua({required String idYeuCau, required String noiDung}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/sua',
        method: 'POST',
        key: 'ycs-sua',
        data: {'id_yeu_cau_chinh_sua': idYeuCau, 'noi_dung_yeu_cau': noiDung},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Cập nhật yêu cầu chỉnh sửa thất bại.');
    }
  }

  /// Hủy 1 yêu cầu (đơn lẻ, theo id_yeu_cau_chinh_sua) — POST
  /// /yeu-cau-chinh-sua/huy. Khác `xoaTheoTepAnh` (hủy theo danh sách
  /// tệp ảnh) và `xoaChuaChotTheoTepAnh` (hủy 1 yêu cầu chưa chốt theo
  /// tệp ảnh).
  Future<void> huy({required String idYeuCau}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/huy',
        method: 'POST',
        key: 'ycs-huy',
        data: {'id_yeu_cau_chinh_sua': idYeuCau},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Hủy yêu cầu chỉnh sửa thất bại.');
    }
  }

  Future<void> xoaTheoTepAnh({required List<String> tepAnhIds}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/xoa-theo-tep-anh',
        method: 'POST',
        key: 'ycs-xoa-theo-tep-anh',
        data: {'tep_anh_ids': tepAnhIds},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Hủy yêu cầu chỉnh sửa thất bại.');
    }
  }

  Future<void> xoaChuaChotTheoTepAnh({required String idTepAnh}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/xoa-chua-chot-theo-tep-anh',
        method: 'POST',
        key: 'ycs-xoa-chua-chot-mot-anh',
        data: {'tep_anh_id': idTepAnh},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Xóa yêu cầu chỉnh sửa thất bại.');
    }
  }

  /// Lịch sử yêu cầu chỉnh sửa theo tệp ảnh — GET (query params), không
  /// phải POST như bản trước mình viết nhầm.
  Future<List<Map<String, dynamic>>> lichSu({required String idTepAnh}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/lich-su-theo-tep-anh',
        method: 'GET',
        key: 'ycs-lich-su-$idTepAnh',
        params: {'tep_anh_id': idTepAnh},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Không tải được lịch sử.');
    }
    return _unwrapList(kq.payload);
  }

  /// Danh sách yêu cầu chỉnh sửa (chung, có bộ lọc qua params) — GET
  /// /yeu-cau-chinh-sua/danh-sach.
  Future<Map<String, dynamic>> danhSach(Map<String, dynamic> params) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/danh-sach',
        method: 'GET',
        key: 'ycs-danh-sach',
        params: params,
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách yêu cầu.');
    }
    return _unwrap(kq.payload);
  }

  /// Upload kết quả đã chỉnh sửa qua Drive — CHỈ nhân viên có quyền
  /// upload_ket_qua (chủ studio/editor) — POST
  /// /nhan-vien/yeu-cau-chinh-sua/upload-ket-qua.
  Future<Map<String, dynamic>> uploadKetQua({
    required String idYeuCau,
    required String duongDanDrive,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/nhan-vien/yeu-cau-chinh-sua/upload-ket-qua',
        method: 'POST',
        key: 'ycs-upload-ket-qua',
        data: {
          'id_yeu_cau_chinh_sua': idYeuCau,
          'duong_dan_drive': duongDanDrive,
        },
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Ghi nhận ảnh kết quả thất bại.');
    }
    return _unwrap(kq.payload);
  }

  Future<Map<String, dynamic>> taoHangLoat({
    required String idAlbum,
    required List<String> tepAnhIds,
    String? noiDung,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/tao-hang-loat',
        method: 'POST',
        key: 'ycs-tao-hang-loat',
        data: {
          'album_id': idAlbum,
          'tep_anh_ids': tepAnhIds,
          if (noiDung != null && noiDung.trim().isNotEmpty)
            'noi_dung_yeu_cau': noiDung.trim(),
        },
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Gửi yêu cầu chỉnh sửa thất bại.');
    }
    return _unwrap(kq.payload);
  }

  /// Chốt hàng loạt yêu cầu theo id — POST /yeu-cau-chinh-sua/chot.
  Future<Map<String, dynamic>> chot(
      {required List<String> idYeuCauList}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/chot',
        method: 'POST',
        key: 'ycs-chot',
        data: {'id_yeu_cau_chinh_sua_list': idYeuCauList},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Chốt yêu cầu chỉnh sửa thất bại.');
    }
    return _unwrap(kq.payload);
  }

  Future<Map<String, dynamic>> chotTheoTepAnh({
    required List<String> tepAnhIds,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/chot-theo-tep-anh',
        method: 'POST',
        key: 'ycs-chot-theo-tep-anh',
        data: {'tep_anh_ids': tepAnhIds},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Chốt yêu cầu chỉnh sửa thất bại.');
    }
    return _unwrap(kq.payload);
  }

  Future<Map<String, dynamic>> chotTatCaTheoAlbum({
    required String idAlbum,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/chot-tat-ca-theo-album',
        method: 'POST',
        key: 'ycs-chot-tat-ca',
        data: {'album_id': idAlbum},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(
              message: 'Chốt tất cả yêu cầu chỉnh sửa thất bại.');
    }
    return _unwrap(kq.payload);
  }

  Future<void> xoaCungChuaChotTheoAlbum({required String idAlbum}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/yeu-cau-chinh-sua/xoa-cung-chua-chot-theo-album',
        method: 'POST',
        key: 'ycs-xoa-cung-chua-chot',
        data: {'album_id': idAlbum},
      ),
    );
    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Xóa tất cả yêu cầu chỉnh sửa thất bại.');
    }
  }
}

/// Khớp YCS_TRANG_THAI bên React.
class YcsTrangThai {
  static const daYeuCau = 'da_yeu_cau';
  static const daChot = 'da_chot';
  static const hoanThanh = 'hoan_thanh';

  static const label = {
    daYeuCau: 'Đã yêu cầu',
    daChot: 'Đã chốt',
    hoanThanh: 'Đã sửa xong',
  };
}
