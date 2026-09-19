import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Đọc biến môi trường từ file .env
class Env {
  Env._();

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Không có file .env thì dùng giá trị mặc định bên dưới
    }
  }

  static String _get(String key, String fallback) =>
      dotenv.isInitialized ? (dotenv.env[key] ?? fallback) : fallback;

  static String get apiBaseUrl => _get('API_BASE_URL', 'https://api.example.com');
  static String get appName => _get('APP_NAME', 'PhotoFlow');
}
