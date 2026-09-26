import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_text_input.dart';
import '../../routes/app_routes.dart';
import '../../stores/auth_store.dart';
import '../../utils/validators.dart';

/// Khối giao diện form đăng nhập. View được phép đọc stores/ và ghép từ
/// components/ (theo đúng chiều phụ thuộc pages -> views -> components).
///
/// Không tự hiện lỗi bằng SnackBar nữa — AuthApi.dangNhap() đã tự hiện
/// toast thành công/thất bại dựa trên code/message của BE (xem
/// apis/api_notify.dart), nên view chỉ cần lo validate + điều hướng.
class LoginFormView extends StatefulWidget {
  const LoginFormView({super.key});

  @override
  State<LoginFormView> createState() => _LoginFormViewState();
}

class _LoginFormViewState extends State<LoginFormView> {
  final _soDienThoaiController = TextEditingController();
  final _matKhauController = TextEditingController();
  String? _loiSoDienThoai;
  String? _loiMatKhau;

  @override
  void dispose() {
    _soDienThoaiController.dispose();
    _matKhauController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _loiSoDienThoai = Validators.isPhoneNumber(_soDienThoaiController.text)
          ? null
          : 'Số điện thoại không hợp lệ (10 số, bắt đầu bằng 0)';
      _loiMatKhau = Validators.minLength(_matKhauController.text, 6)
          ? null
          : 'Mật khẩu tối thiểu 6 ký tự';
    });
    return _loiSoDienThoai == null && _loiMatKhau == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final authStore = context.read<AuthStore>();
    final thanhCong = await authStore.dangNhap(
      soDienThoai: _soDienThoaiController.text.trim(),
      matKhau: _matKhauController.text,
    );

    if (!mounted) return;

    // Toast thành công/thất bại đã tự hiện ở tầng apis/ (notifyApiByCode).
    // Ở đây chỉ còn lo điều hướng khi thành công.
    if (thanhCong) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.album,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthStore>().isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextInput(
          controller: _soDienThoaiController,
          label: 'Số điện thoại',
          type: AppTextInputType.phone,
          hint: '09xxxxxxxx',
          prefixIcon: Icons.phone_outlined,
          errorText: _loiSoDienThoai,
          onChanged: (_) {
            // Bỏ lỗi ngay khi người dùng gõ lại, giống hành vi cũ (lỗi chỉ
            // còn hiện đến khi _validate() chạy lại lúc bấm Đăng nhập).
            if (_loiSoDienThoai != null) setState(() => _loiSoDienThoai = null);
          },
        ),
        const SizedBox(height: 16),
        AppTextInput(
          controller: _matKhauController,
          label: 'Mật khẩu',
          type: AppTextInputType.password,
          prefixIcon: Icons.lock_outline,
          errorText: _loiMatKhau,
          onChanged: (_) {
            if (_loiMatKhau != null) setState(() => _loiMatKhau = null);
          },
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Đăng nhập',
          isLoading: isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
