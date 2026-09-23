import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API nhân viên qua [ApiRequestManager].
/// Trả về field "data" bên trong envelope: { du_lieu: [...], phan_trang: {...} }.
/// Không map sang model riêng — view tự đọc field thô từ Map.
class NhanVienApi {
  NhanVienApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    String timKiem = '',
    int trang = 1,
    int soLuong = 10,
    String? vaiTro,
    bool? trangThai,
    String? sapXep,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl:
            '/tai-khoan/danh-sach', // TODO: xác nhận đúng path module nhân viên
        method: 'GET',
        key: 'nhan-vien-danh-sach',
        params: {
          'tim_kiem': timKiem,
          'trang': trang,
          'so_luong': soLuong,
          if (vaiTro != null) 'vai_tro': vaiTro,
          if (trangThai != null) 'trang_thai': trangThai,
          if (sapXep != null && sapXep.isNotEmpty) 'sap_xep': sapXep,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được danh sách nhân viên',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách nhân viên.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }
}
