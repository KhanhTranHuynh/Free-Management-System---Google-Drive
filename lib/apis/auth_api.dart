import '../configs/app_constants.dart';
import 'api_client.dart';
import 'models/api_exception.dart';
import 'models/user.dart';

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

/// Gọi các API nhóm xác thực. Chỉ nhận tham số, trả model, KHÔNG hiển thị
/// dialog/snackbar, KHÔNG điều hướng. Lỗi được throw (ApiException) để
/// stores/ xử lý — đúng quy tắc "apis/" trong quy chuẩn thư mục.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<DangNhapKetQua> dangNhap({
    required String soDienThoai,
    required String matKhau,
  }) async {
    final body = await _client.post(
      AppConstants.pathDangNhap,
      data: {
        'so_dien_thoai': soDienThoai,
        'mat_khau': matKhau,
      },
    );

    final code = body['code'];
    if (!AppConstants.laThanhCong(code is int ? code : null)) {
      throw ApiException(
        message: body['message']?.toString() ?? 'Đăng nhập thất bại.',
        messageSystem: body['messageSystem']?.toString(),
        code: code is int ? code : null,
      );
    }

    final data = body['data'];
    if (data is! Map) {
      throw const ApiException(message: 'Dữ liệu người dùng không hợp lệ.');
    }

    return DangNhapKetQua(
      nguoiDung: NhanVien.fromJson(Map<String, dynamic>.from(data)),
      accessToken: body['token']?.toString(),
      refreshToken: body['rToken']?.toString(),
    );
  }
}
