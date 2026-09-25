import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

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
        apiUrl: '/tai-khoan/danh-sach',
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

  Future<Map<String, dynamic>> taoMoi(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tai-khoan/tao-moi',
        method: 'POST',
        key: 'nhan-vien-tao-moi',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tạo được nhân viên mới',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tạo được nhân viên mới.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> capNhat(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/tai-khoan/cap-nhat',
        method: 'POST',
        key: 'nhan-vien-cap-nhat',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không cập nhật được nhân viên',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không cập nhật được nhân viên.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }
}
