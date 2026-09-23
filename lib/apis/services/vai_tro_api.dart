import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API danh sách vai trò (dùng làm options cho filter "Vai trò" ở
/// màn hình nhân viên). Cùng mẫu với NhanVienApi/DanhMucKhachHangApi.
class VaiTroApi {
  VaiTroApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    int trang = 1,
    int soLuong = 100,
    bool? trangThai,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/vai-tro/danh-sach', // TODO: xác nhận đúng path module vai trò
        method: 'GET',
        key: 'vai-tro-danh-sach',
        params: {
          'trang': trang,
          'so_luong': soLuong,
          if (trangThai != null) 'trang_thai': trangThai,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được danh sách vai trò',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách vai trò.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }
}
