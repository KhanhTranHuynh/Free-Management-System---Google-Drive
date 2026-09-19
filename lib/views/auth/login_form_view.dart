import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/app_button.dart';
import '../../components/app_text_field.dart';
import '../../configs/app_spacing.dart';
import '../../routes/app_routes.dart';
import '../../stores/auth_store.dart';
import '../../utils/validators.dart';

class LoginFormView extends StatefulWidget {
  const LoginFormView({super.key});

  @override
  State<LoginFormView> createState() => _LoginFormViewState();
}

class _LoginFormViewState extends State<LoginFormView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@test.com');
  final _passCtrl = TextEditingController(text: '123456');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await context
        .read<AuthStore>()
        .login(_emailCtrl.text.trim(), _passCtrl.text);

    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Email',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Mật khẩu',
            controller: _passCtrl,
            obscureText: true,
            validator: Validators.password,
          ),
          if (auth.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              auth.error!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Đăng nhập',
            isLoading: auth.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}