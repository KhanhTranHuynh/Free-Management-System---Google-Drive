import '../../configs/app_constants.dart';
import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';
import '../models/user.dart';

/// Kết quả đăng nhập thành công: thông tin đầy đủ của người dùng + cặp
/// token. Tầng stores/ sẽ đọc object này để lưu vào AuthStore.
class DangNhapKetQua {
  final NhanVien nguoiDung;
  final String? accessToken;
  final String? refreshToken;

  const DangNhapKetQua({
    required this.nguoiDung,
    required this.accessToken,
    required this.refreshToken,
  });
}

/// Gọi các API nhóm xác thực qua [ApiRequestManager]. Chỉ nhận tham số,
/// trả model, KHÔNG hiển thị dialog, KHÔNG điều hướng — RIÊNG toast được
/// hiện tự động qua [notifyApiByCode] ngay sau khi có response, dựa trên
/// "code"/"message" của BE (xem apis/api_notify.dart), y hệt cách
/// notifyApiByCode() được gọi ngay sau callApi() ở bản React gốc.
class AuthApi {
  AuthApi(this._manager);

  final ApiRequestManager _manager;

  /// [thongBao]: true (mặc định) = tự hiện toast thành công/thất bại theo
  /// đúng code/message BE trả về. Đặt false nếu màn hình gọi muốn tự xử lý
  /// hiển thị lỗi theo cách khác (vd hiện lỗi ngay dưới ô nhập thay vì toast).
  Future<DangNhapKetQua> dangNhap({
    required String soDienThoai,
    required String matKhau,
    bool thongBao = true,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/public/xac-thuc/dang-nhap',
        key: 'dang-nhap',
        data: {
          'so_dien_thoai': soDienThoai,
          'mat_khau': matKhau,
        },
        showOverlay: true,
      ),
    );

    if (thongBao) {
      // code > 0 -> toast xanh lấy message "Đăng nhập thành công" từ BE.
      // code <= 0 -> toast đỏ lấy đúng message lỗi BE trả (vd sai mật khẩu).
      notifyApiByCode(
        kq,
        options: const ApiNotifyOptions(
          successMessage: 'Đăng nhập thành công',
          errorMessage: 'Đăng nhập thất bại',
        ),
      );
    }

    // Manager đã kiểm tra envelope (code < 0 => lỗi, kèm message của BE).
    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Đăng nhập thất bại.');
    }

    final envelope = kq.envelope ?? const <String, dynamic>{};
    final data = envelope['data'];
    if (data is! Map) {
      throw const ApiException(message: 'Dữ liệu người dùng không hợp lệ.');
    }

    return DangNhapKetQua(
      nguoiDung: NhanVien.fromJson(Map<String, dynamic>.from(data)),
      accessToken: envelope['token']?.toString(),
      refreshToken: envelope['rToken']?.toString(),
    );
  }
}
