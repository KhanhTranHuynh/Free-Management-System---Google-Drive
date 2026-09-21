import '../../configs/app_constants.dart';
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
/// trả model, KHÔNG hiển thị dialog/snackbar, KHÔNG điều hướng. Lỗi được
/// throw (ApiException) để stores/ xử lý — đúng quy tắc "apis/".
class AuthApi {
  AuthApi(this._manager);

  final ApiRequestManager _manager;

  Future<DangNhapKetQua> dangNhap({
    required String soDienThoai,
    required String matKhau,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: AppConstants.pathDangNhap,
        key: 'dang-nhap',
        data: {
          'so_dien_thoai': soDienThoai,
          'mat_khau': matKhau,
        },
        showOverlay: true,
      ),
    );

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
