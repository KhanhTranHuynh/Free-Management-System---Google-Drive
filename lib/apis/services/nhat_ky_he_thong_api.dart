import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API nhật ký hệ thống qua [ApiRequestManager].
/// Khớp descriptor bên React: GET /nhat-ky-he-thong/danh-sach.
///
/// Chỉ có 1 thao tác duy nhất — xem danh sách (read-only, không có
/// thêm/sửa/xoá). Không truyền sap_xep vì BE cố định
/// ORDER BY created_at DESC (xem comment bên React).
class NhatKyHeThongApi {
  NhatKyHeThongApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    int trang = 1,
    int soLuong = 10,
    String? tenBang,
    String? hanhDong,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/nhat-ky-he-thong/danh-sach',
        method: 'GET',
        key: 'nhat-ky-he-thong-danh-sach',
        params: {
          'trang': trang,
          'so_luong': soLuong,
          if (tenBang != null && tenBang.isNotEmpty) 'ten_bang': tenBang,
          if (hanhDong != null && hanhDong.isNotEmpty) 'hanh_dong': hanhDong,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được nhật ký hệ thống',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được nhật ký hệ thống.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }
}
