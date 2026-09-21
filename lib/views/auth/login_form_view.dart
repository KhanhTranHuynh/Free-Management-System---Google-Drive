import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_text_field.dart';
import '../../routes/app_routes.dart';
import '../../stores/auth_store.dart';
import '../../utils/validators.dart';

/// Khối giao diện form đăng nhập. View được phép đọc stores/ và ghép từ
/// components/ (theo đúng chiều phụ thuộc pages -> views -> components).
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

    if (thanhCong) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
      return;
    }

    final loi = authStore.error ?? 'Đăng nhập thất bại.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthStore>().isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _soDienThoaiController,
          label: 'Số điện thoại',
          hintText: '09xxxxxxxx',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          errorText: _loiSoDienThoai,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _matKhauController,
          label: 'Mật khẩu',
          prefixIcon: Icons.lock_outline,
          obscureText: true,
          errorText: _loiMatKhau,
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
