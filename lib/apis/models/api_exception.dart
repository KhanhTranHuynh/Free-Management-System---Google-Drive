/// Exception chuẩn hoá cho mọi lỗi gọi API.
///
/// BE luôn trả HTTP 200 (guiPhanHoi) và phân biệt lỗi bằng field "code"
/// trong body (code >= 1: thành công, code < 0: lỗi) — xem lại
/// src/api/http.js / callApi.js bản gốc. `apis/` chỉ có nhiệm vụ NHẬN dữ
/// liệu và THROW lỗi (không hiển thị dialog/snackbar); tầng `stores/` là
/// nơi bắt exception này và quyết định hiển thị ra sao.
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

  /// true nếu đây là lỗi hạ tầng thật (network/timeout/CORS), không có
  /// envelope PhanHoiChuan nào từ BE để đọc.
  bool get laLoiHaTang => code == null;

  @override
  String toString() =>
      'ApiException(code: $code, httpStatus: $httpStatus, message: $message)';
}
