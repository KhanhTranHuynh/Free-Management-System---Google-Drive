import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

class TrangThaiAlbumApi {
  TrangThaiAlbumApi(this._manager);

  final ApiRequestManager _manager;

  /// Danh sách trạng thái album — hỗ trợ tìm kiếm, filter, sắp xếp, phân trang.
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
        apiUrl: '/trang-thai-album/danh-sach',
        method: 'GET',
        key: 'trang-thai-album-danh-sach',
        params: {
          'trang': trang,
          'so_luong': soLuong,
          'tim_kiem': timKiem ?? '',
          if (trangThai != null) 'trang_thai': trangThai,
          if (quaHanPhanHoi != null && quaHanPhanHoi.isNotEmpty)
            'qua_han_phan_hoi': quaHanPhanHoi,
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
          const ApiException(
              message: 'Không tải được danh sách trạng thái album.');
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
}
