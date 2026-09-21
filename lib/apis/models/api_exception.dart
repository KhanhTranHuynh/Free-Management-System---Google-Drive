/// Lỗi chung khi gọi API.
class ApiException implements Exception {
  final String message;
  final String? messageSystem;
  final int? code;
  final int? httpStatus;

  const ApiException({
    required this.message,
    this.messageSystem,
    this.code,
    this.httpStatus,
  });

  @override
  String toString() => message;
}
