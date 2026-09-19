/// Lỗi chung khi gọi API, store sẽ bắt và hiển thị message này.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
