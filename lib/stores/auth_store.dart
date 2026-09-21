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
  String? _error;

  NhanVien? get nguoiDung => _nguoiDung;
  Map<String, String>? get quyen => _quyen;
  bool get isLoggedIn => _nguoiDung != null;
  bool get isLoading => _isLoading;
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

  Future<void> dangXuat() async {
    await TokenStorage.clear();
    _nguoiDung = null;
    _quyen = null;
    notifyListeners();
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
