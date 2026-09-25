import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API tổng quan (dashboard trang chủ) qua [ApiRequestManager].
/// Khớp descriptor bên React: GET /tong-quan/dashboard.
///
/// LƯU Ý: response "data" là 1 object lồng nhau (khác với các API danh
/// sách khác đang dùng { du_lieu, phan_trang } phẳng):
/// {
///   album_dang_xu_ly: { du_lieu: [...] },
///   so_luong_album_theo_trang_thai: { chua_xu_ly: n, dang_xu_ly: n, ... },
///   nhat_ky_he_thong: { du_lieu: [...] },
///   lich_phan_cong: { du_lieu: [...] },
/// }
/// -> view tự đọc từng nhánh, không map sang model riêng.
class TongQuanApi {
  TongQuanApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> dashboard({
    String albumTrangThai = 'dang_xu_ly',
    int albumLimit = 5,
    int logLimit = 5,
    int phanCongLimit = 4,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tong-quan/dashboard',
        method: 'GET',
        key: 'tong-quan-dashboard',
        params: {
          'album_trang_thai': albumTrangThai,
          'album_limit': albumLimit,
          'log_limit': logLimit,
          'phan_cong_limit': phanCongLimit,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được dữ liệu tổng quan',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được dữ liệu tổng quan.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }
}
