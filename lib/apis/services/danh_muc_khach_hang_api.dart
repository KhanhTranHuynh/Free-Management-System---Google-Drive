import '../../configs/app_constants.dart';
import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API danh mục khách hàng qua [ApiRequestManager].
/// Trả về nguyên body BE: { du_lieu: [...], phan_trang: {...} }.
class DanhMucKhachHangApi {
  DanhMucKhachHangApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    String timKiem = '',
    int trang = 1,
    int soLuong = 10,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/public/danh-muc-khach-hang/danh-sach',
        method: 'GET',
        key: 'danh-muc-khach-hang-danh-sach',
        params: {
          'tim_kiem': timKiem,
          'trang': trang,
          'so_luong': soLuong,
        },
      ),
    );

    if (!kq.isSuccess) {
      // Chỉ toast khi lỗi, thành công thì im lặng. Bỏ qua khi request bị huỷ.
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được danh mục khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được danh mục khách hàng.');
    }

    return kq.envelope ?? const <String, dynamic>{};
  }
}
