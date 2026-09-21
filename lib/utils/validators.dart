/// Hàm kiểm tra input thuần, không phụ thuộc store/API/giao diện.
class Validators {
  Validators._();

  /// Số điện thoại VN: bắt đầu bằng 0, theo sau 9 chữ số (tổng 10 số).
  static bool isPhoneNumber(String value) {
    final trimmed = value.trim();
    return RegExp(r'^0\d{9}$').hasMatch(trimmed);
  }

  static bool isNotEmpty(String value) => value.trim().isNotEmpty;

  static bool minLength(String value, int min) => value.trim().length >= min;
}
