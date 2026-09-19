import 'api_exception.dart';
import 'models/user.dart';

/// API xác thực.
/// Hiện tại là DỮ LIỆU GIẢ để chạy thử, chưa cần server.
/// Khi có server thật, thay phần thân hàm bằng request HTTP (dio/http)
/// dùng Env.apiBaseUrl, giao diện và store không cần sửa.
class AuthApi {
  Future<User> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // giả lập chờ mạng

    if (email == 'admin@test.com' && password == '123456') {
      return const User(id: '1', name: 'Admin', email: 'admin@test.com');
    }
    throw const ApiException('Sai email hoặc mật khẩu');
  }
}
