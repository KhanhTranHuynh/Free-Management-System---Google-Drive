/// Hằng số chung của app: path API, key lưu trữ, timeout...
/// Không import bất kỳ thư mục nào khác của lib/ (đúng chiều phụ thuộc).
class AppConstants {
  AppConstants._();

  // ---- API paths (khớp với http.js/ApiRequestManager bản gốc) ----
  static const String pathDangNhap = '/public/xac-thuc/dang-nhap';
  static const String pathLamMoiToken = '/public/xac-thuc/lam-moi-token';

  // ---- Key lưu trong flutter_secure_storage ----
  static const String keyAccessToken = 'bms_access_token';
  static const String keyRefreshToken = 'bms_refresh_token';

  // ---- Timeout ----
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ---- PhanHoiChuan: code >= 1 là thành công, code < 0 là lỗi ----
  static bool laThanhCong(int? code) => (code ?? -1) >= 1;
}
