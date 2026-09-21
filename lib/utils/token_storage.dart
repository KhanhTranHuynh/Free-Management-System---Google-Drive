import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../configs/app_constants.dart';

/// Lưu/đọc/xoá cặp accessToken + refreshToken bằng flutter_secure_storage.
///
/// Đặt trong utils/ vì đây là hàm tiện ích thuần về lưu trữ, không phụ
/// thuộc store hay giao diện. `apis/api_client.dart` dùng lớp này để đọc
/// token gắn vào header, và để lưu lại cặp token mới mỗi khi BE trả về
/// (cơ chế "token gối đầu").
class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();

  static Future<void> saveTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    if (accessToken != null && accessToken.isNotEmpty) {
      await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
    }
  }

  static Future<String?> getAccessToken() {
    return _storage.read(key: AppConstants.keyAccessToken);
  }

  static Future<String?> getRefreshToken() {
    return _storage.read(key: AppConstants.keyRefreshToken);
  }

  static Future<void> clear() async {
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
  }
}
