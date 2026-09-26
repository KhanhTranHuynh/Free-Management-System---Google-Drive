import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

class DanhMucKhachHangApi {
  DanhMucKhachHangApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    String timKiem = '',
    int trang = 1,
    int soLuong = 10,
    bool? dangHoatDong,
    String? sapXep,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/danh-muc-khach-hang/danh-sach',
        method: 'GET',
        key: 'danh-muc-khach-hang-danh-sach',
        params: {
          'tim_kiem': timKiem,
          'trang': trang,
          'so_luong': soLuong,
          if (dangHoatDong != null) 'dang_hoat_dong': dangHoatDong,
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
            errorMessage: 'Không tải được danh sách danh mục khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(
              message: 'Không tải được danh sách danh mục khách hàng.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> taoMoi(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/danh-muc-khach-hang/tao-moi',
        method: 'POST',
        key: 'danh-muc-khach-hang-tao-moi',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tạo được danh mục khách hàng mới',
          ),
        );
      }
      throw kq.error ??
          const ApiException(
              message: 'Không tạo được danh mục khách hàng mới.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> capNhat(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/danh-muc-khach-hang/cap-nhat',
        method: 'POST',
        key: 'danh-muc-khach-hang-cap-nhat',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không cập nhật được danh mục khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(
              message: 'Không cập nhật được danh mục khách hàng.');
    }

    final data = kq.payload;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<void> xoa(dynamic id) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/danh-muc-khach-hang/xoa',
        method: 'POST',
        key: 'danh-muc-khach-hang-xoa',
        data: {'id': id},
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không xoá được danh mục khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không xoá được danh mục khách hàng.');
    }
  }

  Future<Map<String, dynamic>> sinhMa({String? idStudioLocal}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/danh-muc-khach-hang/sinh-ma',
        method: 'POST',
        key: 'danh-muc-khach-hang-sinh-ma',
        data: {
          if (idStudioLocal != null) 'id_studio_local': idStudioLocal,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không sinh được mã danh mục khách hàng',
          ),
        );
      }
      throw kq.error ??
          const ApiException(
              message: 'Không sinh được mã danh mục khách hàng.');
    }

    final data = kq.payload;
    // Endpoint này trả 'data' là string thuần (vd 'DMKH0001'), không phải
    // Map như các endpoint khác -> bọc lại thành {'data': ...} để nơi gọi
    // (controller) đọc được qua body['data'] thống nhất.
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data != null) return {'data': data};
    return const <String, dynamic>{};
  }
}
