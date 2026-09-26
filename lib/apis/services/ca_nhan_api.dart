import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API nhóm "cá nhân" (tự thân — KHÔNG có field id nào trong payload,
/// BE luôn lấy tài khoản mục tiêu từ JWT của người đang đăng nhập). Khớp
/// descriptor bên React: src/api/descriptors/nhanVien.js (CaNhanApi).
class CaNhanApi {
  CaNhanApi(this._manager);

  final ApiRequestManager _manager;

  /// POST /ca-nhan/cap-nhat — cập nhật họ tên + màu hiển thị trên lịch.
  ///
  /// Trả về Map dữ liệu tài khoản MỚI NHẤT mà BE trả về, để nơi gọi
  /// (TrangCaNhanView) tự merge vào AuthStore.nguoiDung qua
  /// AuthStore.capNhatThongTinCoBan(). Chấp nhận cả 2 hình dạng response:
  /// { data: {...} } và { data: { item: {...} } }.
  Future<Map<String, dynamic>> capNhat(
    Map<String, dynamic> payload, {
    bool thongBao = true,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/ca-nhan/cap-nhat',
        method: 'POST',
        key: 'ca-nhan-cap-nhat',
        data: payload,
        showOverlay: true,
      ),
    );

    if (thongBao) {
      notifyApiByCode(
        kq,
        options: const ApiNotifyOptions(
          successMessage: 'Cập nhật thông tin thành công',
          errorMessage: 'Cập nhật thông tin thất bại',
        ),
      );
    }

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Cập nhật thông tin thất bại.');
    }

    final data = kq.payload;
    if (data is Map) {
      final item = data['item'];
      if (item is Map) return Map<String, dynamic>.from(item);
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

  /// POST /ca-nhan/doi-mat-khau — đổi mật khẩu đăng nhập.
  /// Không trả dữ liệu gì thêm, chỉ throw nếu thất bại (vd sai mật khẩu cũ).
  Future<void> doiMatKhau({
    required String matKhauCu,
    required String matKhauMoi,
    bool thongBao = true,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/ca-nhan/doi-mat-khau',
        method: 'POST',
        key: 'ca-nhan-doi-mat-khau',
        data: {
          'mat_khau_cu': matKhauCu,
          'mat_khau_moi': matKhauMoi,
        },
        showOverlay: true,
      ),
    );

    if (thongBao) {
      notifyApiByCode(
        kq,
        options: const ApiNotifyOptions(
          successMessage: 'Đổi mật khẩu thành công',
          errorMessage: 'Đổi mật khẩu thất bại',
        ),
      );
    }

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Đổi mật khẩu thất bại.');
    }
  }
}
