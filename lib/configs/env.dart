import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Nguồn duy nhất đọc biến môi trường (.env).
/// Không import bất kỳ thư mục nào khác của lib/ (đúng chiều phụ thuộc).
class Env {
  Env._();

  static String get apiBaseUrl {
    final value = dotenv.env['API_BASE_URL'];
    if (value == null || value.isEmpty) {
      // Fallback an toàn cho môi trường dev nếu quên tạo .env.
      return 'http://localhost:3000/api/v1';
    }
    return value;
  }
}
