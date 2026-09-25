import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

class AlbumApi {
  AlbumApi(this._manager);

  final ApiRequestManager _manager;

  /// Danh sách album — hỗ trợ tìm kiếm, filter, sắp xếp, phân trang.
  /// Trả về { du_lieu, phan_trang, so_luong_theo_trang_thai }.
  Future<Map<String, dynamic>> danhSach({
    required int trang,
    required int soLuong,
    String? idStudioLocal,
    String? timKiem,
    int? trangThai,
    String? quaHanPhanHoi,
    String? tuNgayTao,
    String? denNgayTao,
    String? sapXep,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/danh-sach',
        method: 'GET',
        key: 'album-danh-sach',
        params: {
          'id_studio_local': idStudioLocal,
          'tim_kiem': timKiem ?? '',
          'trang': trang,
          'so_luong': soLuong,
          if (trangThai != null) 'trang_thai': trangThai,
          if (quaHanPhanHoi != null) 'qua_han_phan_hoi': quaHanPhanHoi,
          if (tuNgayTao != null && tuNgayTao.isNotEmpty)
            'tu_ngay_tao': tuNgayTao,
          if (denNgayTao != null && denNgayTao.isNotEmpty)
            'den_ngay_tao': denNgayTao,
          if (sapXep != null && sapXep.isNotEmpty) 'sap_xep': sapXep,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (kq.isCanceled) {
        // Request bị huỷ do có request mới hơn (đổi filter/search liên tục)
        // -> không throw lỗi hiển thị, để ListView tự bỏ qua qua _requestId.
        throw const ApiException(message: '');
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách album.');
    }

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      // Fallback phòng BE đổi cấu trúc, bỏ lớp 'data'.
      return map;
    }
    return const <String, dynamic>{};
  }

  Future<void> doiTrangThai({
    required String idAlbum,
    required String trangThai,
    required void Function() onReloadCanThiet,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/doi-trang-thai',
        method: 'PUT',
        key: 'album-doi-trang-thai',
        params: {
          'id_album': idAlbum,
          'trang_thai': trangThai,
        },
      ),
    );

    notifyApiByCode(
      kq,
      options: ApiNotifyOptions(
        successMessage: 'Đã đổi trạng thái album',
        errorMessage: 'Đổi trạng thái thất bại',
        onSuccess: (_) => onReloadCanThiet(),
      ),
    );
  }
}
