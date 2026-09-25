import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

class TaiKhoanKhachHangApi {
  TaiKhoanKhachHangApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    String timKiem = '',
    int trang = 1,
    int soLuong = 10,
    bool? trangThai,
    String? danhMucKhachHangId,
    bool? choPhepDangNhapPortal,
    String? sapXep,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/khach-hang/danh-sach',
        method: 'GET',
        key: 'khach-hang-danh-sach',
        params: {
          'tim_kiem': timKiem,
          'trang': trang,
          'so_luong': soLuong,
          if (trangThai != null) 'trang_thai': trangThai,
          if (danhMucKhachHangId != null)
            'danh_muc_khach_hang_id': danhMucKhachHangId,
          if (choPhepDangNhapPortal != null)
            'cho_phep_dang_nhap_portal': choPhepDangNhapPortal,
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
            errorMessage: 'Không tải được danh sách khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách khách hàng.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> chiTiet(dynamic id) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/khach-hang/chi-tiet',
        method: 'POST',
        key: 'khach-hang-chi-tiet',
        data: {'id': id},
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được chi tiết khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được chi tiết khách hàng.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> taoMoi(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/khach-hang/tao-moi',
        method: 'POST',
        key: 'khach-hang-tao-moi',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tạo được khách hàng mới',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tạo được khách hàng mới.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> capNhat(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/khach-hang/cap-nhat',
        method: 'POST',
        key: 'khach-hang-cap-nhat',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không cập nhật được khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không cập nhật được khách hàng.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<void> doiTrangThai(dynamic id, bool trangThai) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/khach-hang/doi-trang-thai',
        method: 'POST',
        key: 'khach-hang-doi-trang-thai',
        data: {'id': id, 'trang_thai': trangThai},
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không đổi được trạng thái khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không đổi được trạng thái khách hàng.');
    }
  }

  Future<void> xoa(dynamic id) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/khach-hang/xoa',
        method: 'POST',
        key: 'khach-hang-xoa',
        data: {'id': id},
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không xoá được khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không xoá được khách hàng.');
    }
  }
}
