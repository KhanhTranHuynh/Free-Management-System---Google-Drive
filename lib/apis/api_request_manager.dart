import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../configs/app_constants.dart';
import 'api_client.dart';
import 'models/api_exception.dart';

const String _logTag = '[ApiRequestManager]';

/// Mã lỗi RIÊNG cho case "FE tự chặn vì thiếu quyền theo cache", KHÔNG được
/// trùng với mã lỗi thật nào BE trả về (đặc biệt MA_KHONG_CO_QUYEN = -403).
/// Nhờ vậy tầng gọi phân biệt được "BE thật sự từ chối" với "FE tự đoán
/// trước và chặn" (thường chỉ do cache quyền bị stale).
const int maLoiFeChanThieuQuyen = -900;
const String thongBaoFeChanThieuQuyen =
    'Bạn không có quyền thực hiện thao tác này';

typedef ApiSuccessCallback = FutureOr<void> Function(dynamic data);
typedef ApiErrorCallback = FutureOr<void> Function(ApiException error);
typedef PermissionChecker = bool Function(String module, String hanhDong);

/// Khai báo quyền cần có để gọi 1 request, vd ApiQuyen('ALBUM', 'xem').
class ApiQuyen {
  const ApiQuyen(this.module, this.hanhDong);
  final String module;
  final String hanhDong;

  @override
  String toString() => '$module:$hanhDong';
}

/// Mô tả 1 request trong batch (tương đương phần tử của `apiList` bản JS).
class ApiRequest {
  const ApiRequest({
    required this.apiUrl,
    this.method = 'POST',
    this.data,
    this.dataFactory,
    this.params,
    this.headers,
    this.timeout,
    this.cancelToken,
    this.baseUrl,
    this.authScope,
    this.onSendProgress,
    this.responseType,
    this.key,
    this.showOverlay = false,
    this.quyen,
    this.onSuccess,
    this.onError,
  });

  final String apiUrl;
  final String method;

  /// Body gửi lên (Map, List, FormData...). Bị bỏ qua nếu có [dataFactory].
  final dynamic data;

  /// Tạo body ngay trước khi gửi (vd cần đọc file/token mới nhất).
  final Future<dynamic> Function()? dataFactory;

  /// Query string (dùng cho GET).
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? headers;

  /// Timeout chờ phản hồi riêng cho request này.
  final Duration? timeout;

  /// Thay cho AbortController.signal bên JS: gọi cancelToken.cancel().
  final CancelToken? cancelToken;

  /// Trỏ sang server khác (vd media server), vẫn đi qua interceptor token.
  final String? baseUrl;

  /// Để dành cho phiên không phải nhân viên (vd khách xem album). Được
  /// đưa vào `options.extra['authScope']` để ApiClient._onRequest đọc.
  final String? authScope;

  /// Theo dõi % upload file.
  final ProgressCallback? onSendProgress;
  final ResponseType? responseType;

  /// Khoá để tra kết quả trong batch (mặc định "METHOD apiUrl").
  final String? key;

  /// Bật overlay riêng cho request này (bị bỏ qua nếu cả batch đã bật).
  final bool showOverlay;

  /// FE tự chặn nếu cache quyền không cho phép. CHỈ là tối ưu UX/băng
  /// thông, KHÔNG thay thế kiểm tra quyền ở BE.
  final ApiQuyen? quyen;

  /// Nhận nguyên envelope `{data, message, code, ...}` khi thành công.
  final ApiSuccessCallback? onSuccess;
  final ApiErrorCallback? onError;
}

enum ApiResultStatus { success, error, skipped }

/// Kết quả của 1 request.
class ApiResult {
  const ApiResult({
    required this.key,
    required this.apiUrl,
    required this.method,
    required this.status,
    this.statusCode,
    this.data,
    this.error,
    this.isCanceled = false,
    this.isFrontendPermissionDenied = false,
  });

  final String key;
  final String apiUrl;
  final String method;
  final ApiResultStatus status;

  /// Field "code" trong envelope (hoặc mã lỗi tự đặt như -900).
  final int? statusCode;

  /// NGUYÊN response body từ BE (envelope PhanHoiChuan), không unwrap.
  final dynamic data;
  final ApiException? error;
  final bool isCanceled;
  final bool isFrontendPermissionDenied;

  bool get isSuccess => status == ApiResultStatus.success;

  Map<String, dynamic>? get envelope =>
      data is Map ? Map<String, dynamic>.from(data as Map) : null;

  /// Field "data" bên trong envelope.
  dynamic get payload => envelope?['data'];

  /// Trả về `data` của envelope, hoặc throw [ApiException] nếu request lỗi.
  /// Tiện cho tầng stores/: `final ds = (await mgr.send(...)).payloadOrThrow;`
  dynamic get payloadOrThrow {
    if (isSuccess) return payload;
    throw error ?? const ApiException(message: 'Yêu cầu không được thực hiện.');
  }
}

/// Kết quả của cả batch.
class ApiBatchResult {
  const ApiBatchResult({
    required this.batchId,
    required this.parallel,
    required this.results,
  });

  final String batchId;
  final bool parallel;
  final List<ApiResult> results;

  int get successCount =>
      results.where((r) => r.status == ApiResultStatus.success).length;
  int get errorCount =>
      results.where((r) => r.status == ApiResultStatus.error).length;
  int get skippedCount =>
      results.where((r) => r.status == ApiResultStatus.skipped).length;
  bool get hasError => errorCount > 0;

  ApiResult? byKey(String key) {
    for (final r in results) {
      if (r.key == key) return r;
    }
    return null;
  }
}

class _BatchTask {
  _BatchTask({
    required this.apiList,
    required this.parallel,
    required this.showOverlay,
    required this.stopOnError,
    required this.batchId,
  });

  final List<ApiRequest> apiList;
  final bool parallel;
  final bool? showOverlay;
  final bool stopOnError;
  final String batchId;
  final Completer<ApiBatchResult> completer = Completer<ApiBatchResult>();
}

/// ApiRequestManager — tầng điều phối request dùng chung cho toàn app.
///
///  - Hàng đợi batch, giới hạn số batch chạy đồng thời.
///  - Chạy song song hoặc tuần tự trong từng batch (stopOnError).
///  - Overlay loading toàn app bằng reference counter ([overlayVisible]).
///  - Callback success/error độc lập từng request.
///  - Huỷ request bằng CancelToken.
///  - Chặn request thiếu quyền NGAY tại FE (xem [ApiRequest.quyen]).
///
/// Không tạo Dio riêng: mọi request đi qua `ApiClient.instance.dio` để giữ
/// nguyên interceptor gắn token và cơ chế "token gối đầu".
///
/// Quy ước kết quả: request được tính là THÀNH CÔNG khi HTTP ok VÀ envelope
/// có code >= 1 (theo AppConstants.laThanhCong). Code < 0 (lỗi nghiệp vụ)
/// được tính là LỖI, kèm ApiException chứa message/code của BE.
/// Future của sendRequests() luôn resolve; chỉ reject khi manager gặp lỗi
/// nội bộ ngoài dự kiến.
class ApiRequestManager {
  ApiRequestManager._();

  static final ApiRequestManager instance = ApiRequestManager._();

  ApiClient get _client => ApiClient.instance;

  // ---- Config ----
  int _maxConcurrentBatches = 10;
  bool _defaultShowOverlay = false;
  Map<String, dynamic> _defaultHeaders = const {};
  bool _verboseRequestLogging = false;
  PermissionChecker? _permissionChecker;
  void Function(Object error, ApiRequest request)? _onCallbackError;

  // ---- State ----
  final Queue<_BatchTask> _queue = Queue<_BatchTask>();
  int _activeBatchCount = 0;
  int _overlayRefCount = 0;
  int _batchSequence = 0;

  final ValueNotifier<bool> _overlayVisible = ValueNotifier<bool>(false);

  /// UI lắng nghe biến này để hiện/ẩn overlay (xem ApiOverlayHost).
  ValueListenable<bool> get overlayVisible => _overlayVisible;

  int get queueSize => _queue.length;
  int get activeBatchCount => _activeBatchCount;

  /// Cấu hình dùng chung. Tham số null = giữ nguyên giá trị hiện tại. Có thể
  /// gọi lại bất kỳ lúc nào; batch chưa chạy sẽ dùng giá trị mới nhất.
  ///
  /// [permissionChecker]: hàm kiểm tra quyền, thường là `authStore.coQuyen`.
  /// Nếu chưa gắn thì KHÔNG chặn request nào ở FE.
  void configure({
    int? maxConcurrentBatches,
    bool? defaultShowOverlay,
    Map<String, dynamic>? defaultHeaders,
    bool? verboseRequestLogging,
    PermissionChecker? permissionChecker,
    void Function(Object error, ApiRequest request)? onCallbackError,
  }) {
    if (maxConcurrentBatches != null) {
      if (maxConcurrentBatches < 1) {
        throw ArgumentError('maxConcurrentBatches phải là số nguyên >= 1.');
      }
      _maxConcurrentBatches = maxConcurrentBatches;
    }
    if (defaultShowOverlay != null) _defaultShowOverlay = defaultShowOverlay;
    if (defaultHeaders != null) _defaultHeaders = Map.of(defaultHeaders);
    if (verboseRequestLogging != null) {
      _verboseRequestLogging = verboseRequestLogging;
    }
    if (permissionChecker != null) _permissionChecker = permissionChecker;
    if (onCallbackError != null) _onCallbackError = onCallbackError;

    _log('configure()', {
      'maxConcurrentBatches': _maxConcurrentBatches,
      'defaultShowOverlay': _defaultShowOverlay,
      'verbose': _verboseRequestLogging,
      'hasPermissionChecker': _permissionChecker != null,
    });

    // Tăng concurrency lúc queue đang có dữ liệu -> lấy thêm batch chạy ngay.
    _schedule();
  }

  // ---------------------------------------------------------------------
  // API công khai
  // ---------------------------------------------------------------------

  /// Gọi 1 request đơn lẻ, trả về [ApiResult]. Không throw khi API lỗi —
  /// đọc `result.isSuccess` / `result.error`, hoặc dùng `payloadOrThrow`.
  Future<ApiResult> send(ApiRequest request) async {
    final batch = await sendRequests(apiList: [request], parallel: true);
    return batch.results.first;
  }

  /// Thêm 1 batch vào queue.
  Future<ApiBatchResult> sendRequests({
    required List<ApiRequest> apiList,
    required bool parallel,
    bool? showOverlay,
    bool stopOnError = false,
    String? batchId,
  }) {
    for (var i = 0; i < apiList.length; i++) {
      if (apiList[i].apiUrl.trim().isEmpty) {
        throw ArgumentError('apiList[$i].apiUrl is required.');
      }
    }

    final id = (batchId != null && batchId.trim().isNotEmpty)
        ? batchId.trim()
        : _createBatchId();

    final task = _BatchTask(
      apiList:
          List<ApiRequest>.of(apiList), // copy để caller sửa không ảnh hưởng
      parallel: parallel,
      showOverlay: showOverlay,
      stopOnError: stopOnError,
      batchId: id,
    );

    _log('sendRequests() enqueue', {
      'batchId': id,
      'parallel': parallel,
      'requestCount': apiList.length,
      'queueSizeBefore': _queue.length,
    });

    _queue.add(task);
    _schedule();
    return task.completer.future;
  }

  // ---------------------------------------------------------------------
  // Scheduler
  // ---------------------------------------------------------------------

  void _schedule() {
    while (_activeBatchCount < _maxConcurrentBatches && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      _activeBatchCount++;

      _log('schedule() start batch', {
        'batchId': task.batchId,
        'active': _activeBatchCount,
        'remaining': _queue.length,
      });

      _executeBatch(task).then(
        (result) => task.completer.complete(result),
        onError: (Object e, StackTrace s) {
          _log('batch rejected', {'batchId': task.batchId, 'error': e});
          task.completer.completeError(e, s);
        },
      ).whenComplete(() {
        _activeBatchCount--;
        _schedule();
      });
    }
  }

  Future<ApiBatchResult> _executeBatch(_BatchTask task) async {
    final showOverlay = task.showOverlay ?? _defaultShowOverlay;
    final stopwatch = Stopwatch()..start();

    if (showOverlay) _acquireOverlay();

    try {
      final results = task.parallel
          ? await _executeParallel(task.apiList, showOverlay)
          : await _executeSequential(
              task.apiList, showOverlay, task.stopOnError);

      final batch = ApiBatchResult(
        batchId: task.batchId,
        parallel: task.parallel,
        results: results,
      );

      _log('executeBatch() done', {
        'batchId': task.batchId,
        'success': batch.successCount,
        'error': batch.errorCount,
        'skipped': batch.skippedCount,
        'ms': stopwatch.elapsedMilliseconds,
      });

      if (batch.hasError) {
        _log('executeBatch() completed with errors', {
          'batchId': task.batchId,
          'failed': results
              .where((r) => r.status == ApiResultStatus.error)
              .map((r) => '${r.key} (code: ${r.statusCode})')
              .toList(),
        });
      }
      return batch;
    } finally {
      if (showOverlay) _releaseOverlay();
    }
  }

  Future<List<ApiResult>> _executeParallel(
    List<ApiRequest> apiList,
    bool batchShowOverlay,
  ) {
    return Future.wait(
      apiList.map((r) => _executeRequest(r, batchShowOverlay)),
    );
  }

  Future<List<ApiResult>> _executeSequential(
    List<ApiRequest> apiList,
    bool batchShowOverlay,
    bool stopOnError,
  ) async {
    final results = <ApiResult>[];

    for (var i = 0; i < apiList.length; i++) {
      final result = await _executeRequest(apiList[i], batchShowOverlay);
      results.add(result);

      if (stopOnError && result.status == ApiResultStatus.error) {
        _log('executeSequential() stopOnError triggered', {
          'apiUrl': apiList[i].apiUrl,
          'skipped': apiList.length - i - 1,
        });
        for (var j = i + 1; j < apiList.length; j++) {
          results.add(_skippedResult(apiList[j]));
        }
        break;
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------
  // Thực thi 1 request
  // ---------------------------------------------------------------------

  Future<ApiResult> _executeRequest(
    ApiRequest request,
    bool batchShowOverlay,
  ) async {
    final method = request.method.toUpperCase();
    final key = _requestKey(request, method);
    final tag = '[$method ${request.apiUrl}]';
    final stopwatch = Stopwatch()..start();

    // FE tự chặn NGAY — trước overlay, trước dataFactory, trước khi gọi mạng.
    final quyen = request.quyen;
    if (quyen != null && !_coQuyen(quyen)) {
      _log('$tag blocked by FE quyen check', {'key': key, 'quyen': quyen});

      const error = ApiException(
        message: thongBaoFeChanThieuQuyen,
        code: maLoiFeChanThieuQuyen,
      );
      await _safeErrorCallback(request, error);

      return ApiResult(
        key: key,
        apiUrl: request.apiUrl,
        method: method,
        status: ApiResultStatus.error,
        statusCode: maLoiFeChanThieuQuyen,
        error: error,
        isFrontendPermissionDenied: true,
      );
    }

    final requestShowOverlay = !batchShowOverlay && request.showOverlay;
    if (requestShowOverlay) _acquireOverlay();

    _log('$tag start', {
      'key': key,
      'authScope': request.authScope,
      if (_verboseRequestLogging) 'params': request.params,
    });

    try {
      final body = request.dataFactory != null
          ? await request.dataFactory!()
          : request.data;

      final headers = <String, dynamic>{
        ..._defaultHeaders,
        ...?request.headers,
      };

      final response = await _client.dio.request<dynamic>(
        _resolveUrl(request),
        data: body, // FormData: Dio tự đặt multipart + boundary
        queryParameters: request.params,
        cancelToken: request.cancelToken,
        onSendProgress: request.onSendProgress,
        options: Options(
          method: method,
          headers: headers,
          receiveTimeout: request.timeout,
          responseType: request.responseType,
          extra: {
            if (request.authScope != null) 'authScope': request.authScope
          },
        ),
      );

      final responseBody = response.data;

      // Có envelope PhanHoiChuan -> kiểm tra code (>=1 thành công, <0 lỗi).
      if (responseBody is Map && responseBody.containsKey('code')) {
        final code =
            responseBody['code'] is int ? responseBody['code'] as int : null;

        if (!AppConstants.laThanhCong(code)) {
          final error = ApiException(
            message: responseBody['message']?.toString() ?? 'Yêu cầu thất bại.',
            messageSystem: responseBody['messageSystem']?.toString(),
            code: code,
            httpStatus: response.statusCode,
          );

          _log('$tag business error', {
            'key': key,
            'code': code,
            'message': error.message,
            'ms': stopwatch.elapsedMilliseconds,
          });

          await _safeErrorCallback(request, error);

          return ApiResult(
            key: key,
            apiUrl: request.apiUrl,
            method: method,
            status: ApiResultStatus.error,
            statusCode: code,
            data: responseBody,
            error: error,
          );
        }
      }

      _log('$tag success', {
        'key': key,
        'ms': stopwatch.elapsedMilliseconds,
        if (_verboseRequestLogging) 'data': responseBody,
      });

      await _safeSuccessCallback(request, responseBody);

      return ApiResult(
        key: key,
        apiUrl: request.apiUrl,
        method: method,
        status: ApiResultStatus.success,
        statusCode: responseBody is Map && responseBody['code'] is int
            ? responseBody['code'] as int
            : null,
        data: responseBody,
      );
    } catch (e) {
      final error = _normalizeError(e);
      final canceled = e is DioException && e.type == DioExceptionType.cancel;

      _log(canceled ? '$tag canceled' : '$tag failed', {
        'key': key,
        'code': error.code,
        'httpStatus': error.httpStatus,
        'message': error.message,
        'ms': stopwatch.elapsedMilliseconds,
      });

      await _safeErrorCallback(request, error);

      return ApiResult(
        key: key,
        apiUrl: request.apiUrl,
        method: method,
        status: ApiResultStatus.error,
        statusCode: error.code ?? error.httpStatus,
        data: e is DioException ? e.response?.data : null,
        error: error,
        isCanceled: canceled,
      );
    } finally {
      if (requestShowOverlay) _releaseOverlay();
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  bool _coQuyen(ApiQuyen quyen) {
    final checker = _permissionChecker;
    if (checker == null) return true; // chưa gắn checker -> không chặn ở FE
    return checker(quyen.module, quyen.hanhDong);
  }

  /// Dio không có baseUrl theo từng request -> tự ghép khi cần trỏ sang
  /// server khác.
  String _resolveUrl(ApiRequest request) {
    final base = request.baseUrl;
    if (base == null || base.isEmpty) return request.apiUrl;
    final b = base.replaceAll(RegExp(r'/+$'), '');
    final p = request.apiUrl.replaceAll(RegExp(r'^/+'), '');
    return '$b/$p';
  }

  ApiException _normalizeError(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      final body = error.response?.data;
      final status = error.response?.statusCode;

      if (body is Map) {
        return ApiException(
          message: body['message']?.toString() ?? 'Yêu cầu thất bại.',
          messageSystem: body['messageSystem']?.toString(),
          code: body['code'] is int ? body['code'] as int : null,
          httpStatus: status,
        );
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(
            message: 'Máy chủ phản hồi quá lâu, vui lòng thử lại.',
            httpStatus: status,
          );
        case DioExceptionType.cancel:
          return const ApiException(message: 'Yêu cầu đã bị huỷ.');
        case DioExceptionType.connectionError:
          return ApiException(
            message: 'Không thể kết nối tới máy chủ.',
            httpStatus: status,
          );
        default:
          return ApiException(
            message: error.message ?? 'Không thể kết nối tới máy chủ.',
            httpStatus: status,
          );
      }
    }

    return ApiException(message: error.toString());
  }

  ApiResult _skippedResult(ApiRequest request) {
    final method = request.method.toUpperCase();
    return ApiResult(
      key: _requestKey(request, method),
      apiUrl: request.apiUrl,
      method: method,
      status: ApiResultStatus.skipped,
    );
  }

  String _requestKey(ApiRequest request, String method) {
    final k = request.key?.trim();
    return (k != null && k.isNotEmpty) ? k : '$method ${request.apiUrl}';
  }

  String _createBatchId() {
    _batchSequence++;
    return 'batch-${DateTime.now().millisecondsSinceEpoch}-$_batchSequence';
  }

  Future<void> _safeSuccessCallback(ApiRequest request, dynamic data) async {
    final cb = request.onSuccess;
    if (cb == null) return;
    try {
      await cb(data);
    } catch (e) {
      _log('onSuccess threw', {'apiUrl': request.apiUrl, 'error': e});
      _handleCallbackError(e, request);
    }
  }

  Future<void> _safeErrorCallback(
      ApiRequest request, ApiException error) async {
    final cb = request.onError;
    if (cb == null) return;
    try {
      await cb(error);
    } catch (e) {
      _log('onError threw', {'apiUrl': request.apiUrl, 'error': e});
      _handleCallbackError(e, request);
    }
  }

  void _handleCallbackError(Object error, ApiRequest request) {
    try {
      _onCallbackError?.call(error, request);
    } catch (e) {
      // Không để lỗi của error handler làm hỏng scheduler.
      _log('onCallbackError handler threw', {'error': e});
    }
  }

  // ---- Overlay (reference counter) ----

  void _acquireOverlay() {
    _overlayRefCount++;
    _emitOverlay();
  }

  void _releaseOverlay() {
    if (_overlayRefCount > 0) _overlayRefCount--;
    _emitOverlay();
  }

  /// Cập nhật ở microtask để không bao giờ đổi state UI ngay trong lúc
  /// Flutter đang build (vd request gọi từ initState), đồng thời gộp các lần
  /// acquire/release liên tiếp thành 1 lần thông báo.
  void _emitOverlay() {
    scheduleMicrotask(() {
      final show = _overlayRefCount > 0;
      if (_overlayVisible.value != show) _overlayVisible.value = show;
    });
  }

  void _log(String message, [Map<String, Object?>? extra]) {
    if (!kDebugMode) return;
    debugPrint(
      extra == null || extra.isEmpty
          ? '$_logTag $message'
          : '$_logTag $message $extra',
    );
  }
}
