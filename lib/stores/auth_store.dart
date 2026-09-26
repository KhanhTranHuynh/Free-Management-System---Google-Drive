import 'package:flutter/foundation.dart';

import '../apis/services/auth_api.dart';
import '../apis/models/api_exception.dart';
import '../apis/models/user.dart';
import '../utils/token_storage.dart';

/// Store phiên đăng nhập — nơi DUY NHẤT gọi apis/ cho nghiệp vụ xác thực.
///
/// Theo đúng yêu cầu: sau khi đăng nhập thành công,
///  - `nguoiDung`: lưu NGUYÊN thông tin đầy đủ của người dùng (1 biến).
///  - `quyen`   : lưu RIÊNG bản đồ quyền để tái sử dụng ở nơi khác mà
///                không cần đào qua nguoiDung.quyen (1 biến khác).
class AuthStore extends ChangeNotifier {
  AuthStore(this._api);

  final AuthApi _api;

  NhanVien? _nguoiDung;
  Map<String, String>? _quyen;
  bool _isLoading = false;
  bool _isLoggingOut = false;
  String? _error;

  NhanVien? get nguoiDung => _nguoiDung;
  Map<String, String>? get quyen => _quyen;
  bool get isLoggedIn => _nguoiDung != null;
  bool get isLoading => _isLoading;
  bool get isLoggingOut => _isLoggingOut;
  String? get error => _error;

  /// Đăng nhập bằng số điện thoại + mật khẩu.
  /// Trả về true nếu thành công; lỗi (nếu có) đọc qua getter `error`.
  Future<bool> dangNhap({
    required String soDienThoai,
    required String matKhau,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ketQua = await _api.dangNhap(
        soDienThoai: soDienThoai,
        matKhau: matKhau,
      );

      _nguoiDung = ketQua.nguoiDung;
      _quyen = ketQua.nguoiDung.quyen;
      _isLoading = false;
      notifyListeners();

      // In dữ liệu vừa lưu ra console để tiện kiểm tra (theo yêu cầu).
      debugPrint('[AuthStore] Đăng nhập thành công, dữ liệu đã lưu vào store:');
      debugPrint('[AuthStore] nguoiDung = ${_nguoiDung?.toJson()}');
      debugPrint('[AuthStore] quyen = $_quyen');

      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Đăng nhập thất bại. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gọi BE huỷ phiên (`/xac-thuc/dang-xuat`) rồi tháo dữ liệu phiên đăng
  /// nhập ở client (token trong TokenStorage + nguoiDung/quyen trong store).
  ///
  /// Dù API đăng xuất thành công hay lỗi (mất mạng, token hết hạn...), dữ
  /// liệu ở client vẫn LUÔN được tháo ra trong `finally`, để tránh người
  /// dùng bị kẹt ở trạng thái "tưởng đã đăng xuất" nhưng UI vẫn coi là
  /// đang đăng nhập.
  Future<void> dangXuat() async {
    _isLoggingOut = true;
    notifyListeners();

    try {
      await _api.dangXuat();
    } catch (e) {
      // Toast lỗi (nếu có) đã tự hiện ở tầng apis/ (notifyApiByCode).
      // Ở đây chỉ log lại để tiện debug, không chặn việc dọn dẹp phía dưới.
      debugPrint(
          '[AuthStore] Gọi API đăng xuất lỗi (vẫn tiếp tục dọn dẹp): $e');
    } finally {
      await TokenStorage.clear();
      _nguoiDung = null;
      _quyen = null;
      _isLoggingOut = false;
      notifyListeners();

      debugPrint('[AuthStore] Đã tháo dữ liệu phiên đăng nhập khỏi store.');
    }
  }

  /// Kiểm tra nhanh module/hành động có nằm trong quyền đang lưu hay
  /// không (vd coQuyen('ALBUM', 'xem')). Chỉ dùng để ẩn/hiện UI cho mượt
  /// — KHÔNG thay thế kiểm tra quyền thật ở BE.
  bool coQuyen(String module, String hanhDong) {
    final chuoiQuyen = _quyen?[module];
    if (chuoiQuyen == null) return false;
    return chuoiQuyen.split(',').map((e) => e.trim()).contains(hanhDong);
  }
}
