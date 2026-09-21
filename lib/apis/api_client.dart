import 'package:dio/dio.dart';

import '../configs/app_constants.dart';
import '../configs/env.dart';
import '../utils/token_storage.dart';
import 'models/api_exception.dart';

/// Client HTTP dùng chung cho toàn app — tương đương `http.js` ở bản React
/// gốc: 1 instance Dio duy nhất, có interceptor gắn token và xử lý cơ chế
/// "token gối đầu".
///
/// BE (guiPhanHoi) LUÔN trả HTTP 200 và phân biệt thành công/lỗi bằng
/// field "code" trong body: code >= 1 là thành công, code < 0 là lỗi.
/// Token/refresh token mới (nếu middleware cấp lại trong lúc request đang
/// chạy) nằm ở TOP-LEVEL của body: { token, rToken }, KHÔNG lồng trong
/// "data". Mỗi lần nhận response, client tự lưu đè cặp token mới nhất
/// xuống secure storage — đây chính là cơ chế "gối đầu" liên tục mà
/// không cần gọi riêng API refresh.
///
/// Không đặt code giao diện, không hiển thị dialog ở đây — apis/ chỉ có
/// nhiệm vụ gọi mạng và throw ApiException, tầng stores/ mới quyết định
/// hiển thị lỗi ra sao.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // authScope riêng cho các phiên không phải nhân viên hệ thống (vd
    // khách xem album) có thể mở rộng ở đây bằng cách đọc
    // options.extra['authScope'] và dùng cặp token khác — hiện tại app
    // chỉ có 1 phiên đăng nhập duy nhất (nhân viên).
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      options.headers['rtoken'] = refreshToken;
    }

    handler.next(options);
  }

  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final body = response.data;
    if (body is Map) {
      // 👇 Token gối đầu: BE nhúng token/rToken mới ở top-level bất kỳ lúc
      // nào middleware thấy cần cấp lại -> luôn ghi đè xuống storage,
      // không cần đợi 401 rồi mới refresh.
      final tokenMoi = body['token'] as String?;
      final refreshTokenMoi = body['rToken'] as String?;
      if ((tokenMoi != null && tokenMoi.isNotEmpty) ||
          (refreshTokenMoi != null && refreshTokenMoi.isNotEmpty)) {
        await TokenStorage.saveTokens(
          accessToken: tokenMoi,
          refreshToken: refreshTokenMoi,
        );
      }
    }
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // Lỗi hạ tầng thật (network/timeout/CORS...) — không có envelope
    // PhanHoiChuan nào để đọc "code". Với lỗi xác thực thật (401/403) ở
    // tầng HTTP, xoá token để lần sau không gửi token hỏng lên nữa; màn
    // hình gọi API tự quyết định điều hướng về trang đăng nhập.
    final httpStatus = error.response?.statusCode;
    if (httpStatus == 401 || httpStatus == 403) {
      await TokenStorage.clear();
    }
    handler.next(error);
  }

  /// POST 1 request, trả về NGUYÊN envelope PhanHoiChuan dạng Map.
  /// Không throw khi BE trả code<0 dạng nghiệp vụ bình thường — nơi gọi
  /// (vd auth_api.dart) tự đọc "code" và quyết định throw ApiException
  /// nếu cần, giữ đúng tinh thần "envelope thay vì try/catch khắp nơi"
  /// của callApi.js bản gốc.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        cancelToken: cancelToken,
      );

      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return Map<String, dynamic>.from(body);

      throw const ApiException(
        message: 'Phản hồi từ máy chủ không đúng định dạng.',
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map) {
        throw ApiException(
          message: body['message']?.toString() ?? 'Yêu cầu thất bại.',
          messageSystem: body['messageSystem']?.toString(),
          code: body['code'] is int ? body['code'] as int : null,
          httpStatus: error.response?.statusCode,
        );
      }

      throw ApiException(
        message: error.message ?? 'Không thể kết nối tới máy chủ.',
        httpStatus: error.response?.statusCode,
      );
    }
  }
}
