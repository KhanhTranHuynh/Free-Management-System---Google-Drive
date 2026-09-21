import '../utils/app_toast.dart';
import 'api_request_manager.dart';

/// Kết quả trả về của [notifyApiByCode] — tương đương chuỗi "success"/
/// "error" mà bản JS `notifyApiByCode()` trả về.
enum ApiNotifyOutcome { success, error }

/// Cấu hình cho 1 lần gọi [notifyApiByCode] — map 1-1 với object `options`
/// của bản JS gốc (successMessage, errorMessage, message, silent...).
class ApiNotifyOptions {
  const ApiNotifyOptions({
    this.successMessage = 'Thành công',
    this.errorMessage = 'Thất bại',
    this.message,
    this.silent = false,
    this.silentOnSuccess = false,
    this.silentOnError = false,
    this.onSuccess,
    this.onError,
  });

  /// Message mặc định khi thành công mà BE không trả message riêng.
  final String successMessage;

  /// Message mặc định khi lỗi mà BE không trả message riêng.
  final String errorMessage;

  /// Ép cứng message hiển thị, bỏ qua cả message của BE lẫn 2 message mặc
  /// định ở trên — tương đương `overrideMessage` bên JS.
  final String? message;

  /// true: không hiện toast trong MỌI trường hợp (thành công lẫn lỗi).
  final bool silent;

  /// true: chỉ ẩn toast khi THÀNH CÔNG (lỗi vẫn hiện bình thường).
  final bool silentOnSuccess;

  /// true: chỉ ẩn toast khi LỖI (thành công vẫn hiện bình thường).
  final bool silentOnError;

  final void Function(ApiResult result)? onSuccess;
  final void Function(ApiResult result)? onError;
}

/// Hiện toast THÀNH CÔNG/LỖI dựa trên field "code" của envelope BE trả về,
/// port trực tiếp từ `notifyApiByCode()` (React) sang Dart:
///
///  - code > 0 (ApiRequestManager đã tự quy về [ApiResultStatus.success])
///    => toast xanh, message ưu tiên: `options.message` -> `message` của
///       BE (envelope['message']) -> `options.successMessage`.
///  - code <= 0 hoặc lỗi hạ tầng (network/timeout...)
///    => toast đỏ, message ưu tiên: `options.message` -> message BE trả
///       (đã được ApiRequestManager gói sẵn vào `result.error.message`)
///       -> `options.errorMessage`.
///
/// KHÔNG throw — luôn trả về [ApiNotifyOutcome] để nơi gọi biết kết quả
/// nếu cần xử lý thêm (giống bản JS luôn trả "success"/"error", không
/// throw). Không tự động gọi ở mọi API — nơi nào cần toast tự chủ động
/// gọi hàm này (vd trong apis/services/*.dart hoặc stores/*.dart), giữ
/// đúng nguyên tắc apis/ chỉ throw lỗi, không tự quyết định hiển thị UI
/// trừ khi được yêu cầu rõ ràng qua hàm tiện ích này.
ApiNotifyOutcome notifyApiByCode(
  ApiResult result, {
  ApiNotifyOptions options = const ApiNotifyOptions(),
}) {
  final isSuccess = result.isSuccess;

  final envelope = result.envelope;

  final String? beMessage;
  if (isSuccess) {
    beMessage = envelope == null ? null : envelope['message']?.toString();
  } else {
    beMessage = result.error?.message;
  }

  // Thứ tự ưu tiên message hiển thị: options.message (ép cứng) -> message
  // của BE -> message mặc định (successMessage/errorMessage).
  String finalMessage;
  if (options.message != null && options.message!.trim().isNotEmpty) {
    finalMessage = options.message!;
  } else if (beMessage != null && beMessage.trim().isNotEmpty) {
    finalMessage = beMessage;
  } else if (isSuccess) {
    finalMessage = options.successMessage;
  } else {
    finalMessage = options.errorMessage;
  }

  if (isSuccess) {
    final shouldShow = !options.silent && !options.silentOnSuccess;
    if (shouldShow) AppToast.success(finalMessage);
    options.onSuccess?.call(result);
    return ApiNotifyOutcome.success;
  }

  final shouldShow = !options.silent && !options.silentOnError;
  if (shouldShow) AppToast.error(finalMessage);
  options.onError?.call(result);
  return ApiNotifyOutcome.error;
}
