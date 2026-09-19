/// Các hàm kiểm tra dữ liệu. Trả về null nếu hợp lệ, trả về chuỗi lỗi nếu sai
/// (đúng định dạng của TextFormField.validator).
class Validators {
  Validators._();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'Email không hợp lệ';
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }
}
