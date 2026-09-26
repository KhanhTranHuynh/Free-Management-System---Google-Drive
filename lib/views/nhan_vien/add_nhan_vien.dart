import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';
import '../../utils/mau_sac_util.dart';

// TODO: chuyển sang configs/ (tương đương config.MIN_PASSWORD_LENGTH,
// config.MAX_PASSWORD_LENGTH bên bản React). Riêng màu mặc định giờ lấy
// từ util dùng chung (kMauSacMacDinh) thay vì khai báo lại ở đây.
const int kMinPasswordLength = 6;
const int kMaxPasswordLength = 50;

final RegExp _phoneRegex = RegExp(r'^0\d{9}$');
final RegExp _emailRegex = RegExp(r'^\S+@\S+\.\S+$');

/// Mở modal "Thêm nhân viên".
/// Trả về `true` nếu tạo thành công (View danh sách gọi `reload()`),
/// `null` nếu người dùng hủy.
///
/// [vaiTroOptions]: danh sách vai trò đã tải xong ở View danh sách (mỗi item
/// có `ma_vai_tro`, `ten_hien_thi`) — modal không tự gọi API vai trò.
Future<bool?> showAddNhanVienModal(
  BuildContext context, {
  required List<Map<String, dynamic>> vaiTroOptions,
}) async {
  final controller = _AddNhanVienController(
    NhanVienApi(ApiRequestManager.instance),
  );

  final result = await showAppModal<bool>(
    context,
    title: 'Thêm nhân viên',
    type: AppModalType.bottomSheet,
    closeOnBackdropClick: false, // form nhập dở -> chạm ra ngoài chỉ rung
    builder: (_) => _AddNhanVienBody(
      c: controller,
      vaiTroOptions: vaiTroOptions,
    ),
    footerBuilder: (_) => _AddNhanVienFooter(c: controller),
  );

  // Future của route hoàn tất ngay khi pop, lúc animation đóng vẫn còn
  // chạy và TextField vẫn dùng controller -> dispose trễ để tránh lỗi
  // "used after being disposed".
  Future.delayed(const Duration(milliseconds: 500), controller.dispose);
  return result;
}

// ============================================================
// CONTROLLER: state form + validate + gọi API
// ============================================================
class _AddNhanVienController extends ChangeNotifier {
  _AddNhanVienController(this._api);

  final NhanVienApi _api;

  final hoTen = TextEditingController();
  final soDienThoai = TextEditingController();
  final matKhau = TextEditingController();
  final xacNhanMatKhau = TextEditingController();
  final email = TextEditingController();

  final List<String> vaiTro = [];
  bool trangThai = true; // mặc định Hoạt động
  String mauSac = kMauSacMacDinh;

  bool isSaving = false;
  String? formError;
  final Map<String, String> errors = {};

  void clearError(String key) {
    errors.remove(key);
    // Đổi mật khẩu thì lỗi "không khớp" ở ô xác nhận không còn đúng nữa.
    if (key == 'matKhau') errors.remove('xacNhan');
    formError = null;
    notifyListeners(); // cũng để cập nhật thanh độ mạnh / checklist mật khẩu
  }

  void toggleVaiTro(String ma) {
    vaiTro.contains(ma) ? vaiTro.remove(ma) : vaiTro.add(ma);
    errors.remove('vaiTro');
    notifyListeners();
  }

  void setTrangThai(bool v) {
    trangThai = v;
    notifyListeners();
  }

  void setMauSac(String hex) {
    mauSac = hex;
    errors.remove('mauSac');
    notifyListeners();
  }

  bool _validate() {
    errors.clear();
    final ten = hoTen.text.trim();
    final sdt = soDienThoai.text.trim();
    final mk = matKhau.text.trim();
    final xn = xacNhanMatKhau.text.trim();
    final mail = email.text.trim();

    if (ten.isEmpty) errors['hoTen'] = 'Vui lòng nhập họ tên';

    if (sdt.isEmpty) {
      errors['soDienThoai'] = 'Vui lòng nhập số điện thoại';
    } else if (!_phoneRegex.hasMatch(sdt)) {
      errors['soDienThoai'] = 'Số điện thoại không hợp lệ';
    }

    if (mk.isEmpty) {
      errors['matKhau'] = 'Vui lòng nhập mật khẩu';
    } else if (mk.length < kMinPasswordLength) {
      errors['matKhau'] = 'Mật khẩu phải có ít nhất $kMinPasswordLength ký tự';
    } else if (mk.length > kMaxPasswordLength) {
      errors['matKhau'] = 'Mật khẩu không được quá $kMaxPasswordLength ký tự';
    }

    if (xn.isEmpty) {
      errors['xacNhan'] = 'Vui lòng xác nhận mật khẩu';
    } else if (xn != mk) {
      errors['xacNhan'] = 'Mật khẩu xác nhận không khớp';
    }

    if (mail.isEmpty) {
      errors['email'] = 'Vui lòng nhập email';
    } else if (!_emailRegex.hasMatch(mail)) {
      errors['email'] = 'Email không hợp lệ';
    }

    if (vaiTro.isEmpty) errors['vaiTro'] = 'Vui lòng chọn ít nhất một vai trò';

    if (mauSac.isNotEmpty && !isHexMauSacHopLe(mauSac)) {
      errors['mauSac'] = 'Mã màu không hợp lệ';
    }

    notifyListeners();
    return errors.isEmpty;
  }

  /// true = tạo thành công.
  Future<bool> submit() async {
    if (isSaving) return false;
    if (!_validate()) return false;

    isSaving = true;
    formError = null;
    notifyListeners();

    // KHÔNG gửi xac_nhan_mat_khau — chỉ dùng để validate ở client.
    final payload = <String, dynamic>{
      'so_dien_thoai': soDienThoai.text.trim(),
      'mat_khau': matKhau.text.trim(),
      'ho_ten': hoTen.text.trim(),
      'email': email.text.trim(),
      'vai_tro': List<String>.from(vaiTro),
      'trang_thai': trangThai,
      'mau_sac': mauSac.trim().isEmpty ? null : mauSac.trim(),
    };

    try {
      await _api.taoMoi(payload);
      return true;
    } on ApiException {
      // Toast lỗi đã được hiển thị ở tầng API (notifyApiByCode).
      return false;
    } catch (_) {
      formError = 'Thêm nhân viên thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    hoTen.dispose();
    soDienThoai.dispose();
    matKhau.dispose();
    xacNhanMatKhau.dispose();
    email.dispose();
    super.dispose();
  }
}

// ============================================================
// FOOTER: Hủy / Lưu
// ============================================================
class _AddNhanVienFooter extends StatelessWidget {
  const _AddNhanVienFooter({required this.c});
  final _AddNhanVienController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (ctx, _) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: c.isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: c.isSaving
                  ? null
                  : () async {
                      final ok = await c.submit();
                      if (ok && ctx.mounted) Navigator.of(ctx).pop(true);
                    },
              child: c.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BODY: form
// ============================================================
class _AddNhanVienBody extends StatelessWidget {
  const _AddNhanVienBody({
    required this.c,
    required this.vaiTroOptions,
  });

  final _AddNhanVienController c;
  final List<Map<String, dynamic>> vaiTroOptions;

  ({int score, String label, Color color}) _strength(String pw) {
    if (pw.isEmpty) return (score: 0, label: '', color: Colors.grey);
    var score = 0;
    if (pw.length >= 6) score++;
    if (pw.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;

    if (score <= 1) return (score: 1, label: 'Yếu', color: Colors.redAccent);
    if (score == 2) {
      return (score: 2, label: 'Trung bình', color: Colors.amber);
    }
    if (score == 3) {
      return (score: 3, label: 'Khá', color: Colors.yellow.shade700);
    }
    if (score == 4) return (score: 4, label: 'Mạnh', color: Colors.green);
    return (score: 5, label: 'Rất mạnh', color: Colors.green.shade700);
  }

  Widget _passwordHints() {
    final mk = c.matKhau.text.trim();
    final xn = c.xacNhanMatKhau.text.trim();
    if (mk.isEmpty && xn.isEmpty) return const SizedBox.shrink();

    final s = _strength(mk);
    final reqs = [
      ('Tối thiểu $kMinPasswordLength ký tự', mk.length >= kMinPasswordLength),
      (
        'Khớp với xác nhận mật khẩu',
        mk.isNotEmpty && xn.isNotEmpty && mk == xn
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mk.isNotEmpty) ...[
            Row(
              children: List.generate(5, (i) {
                return Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < s.score ? s.color : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Độ mạnh: ${s.label}',
                style: TextStyle(
                    fontSize: 11, color: s.color, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 4),
          ],
          for (final r in reqs)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(
                    r.$2 ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 16,
                    color: r.$2 ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.$1,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.$2 ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _vaiTroField(BuildContext context) {
    final theme = Theme.of(context);
    // Loại chủ studio khỏi options (không gán chủ studio cho nhân viên mới).
    final options = vaiTroOptions.where((vt) {
      final ma = vt['ma_vai_tro']?.toString();
      return ma != null && ma.isNotEmpty && ma != 'chu_studio';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vai trò *', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Text('Chưa có vai trò nào', style: TextStyle(color: theme.hintColor))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final vt in options)
                FilterChip(
                  label: Text(vt['ten_hien_thi']?.toString() ??
                      vt['ma_vai_tro'].toString()),
                  selected: c.vaiTro.contains(vt['ma_vai_tro'].toString()),
                  onSelected: c.isSaving
                      ? null
                      : (_) => c.toggleVaiTro(vt['ma_vai_tro'].toString()),
                ),
            ],
          ),
        if (c.errors['vaiTro'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              c.errors['vaiTro']!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _mauSacField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Màu hiển thị trên lịch', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        // Bảng màu preset + nút "+" mở bánh xe màu tự do — dùng chung
        // đúng mẫu UI với modal Sửa thông tin cá nhân (sua_thong_tin_modal.dart)
        // qua MauSacGoiYPicker.
        MauSacGoiYPicker(
          mauSacDangChon: c.mauSac,
          onChon: c.isSaving ? (_) {} : c.setMauSac,
          choPhepTuyChinh: true,
          swatchSize: 34,
        ),
        if (c.errors['mauSac'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              c.errors['mauSac']!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Họ tên" là loại `text` -> AppTextInput giữ autocorrect/
            // enableSuggestions bật, tránh bug mất chữ khi gõ tiếng Việt.
            AppTextInput(
              label: 'Họ tên',
              type: AppTextInputType.text,
              controller: c.hoTen,
              hint: 'Nhập họ tên nhân viên',
              required: true,
              requiredMessage: 'Vui lòng nhập họ tên',
              enabled: !c.isSaving,
              errorText: c.errors['hoTen'],
              onChanged: (_) => c.clearError('hoTen'),
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Số điện thoại',
              type: AppTextInputType.phone,
              controller: c.soDienThoai,
              hint: 'Số điện thoại đăng nhập',
              required: true,
              requiredMessage: 'Vui lòng nhập số điện thoại',
              enabled: !c.isSaving,
              errorText: c.errors['soDienThoai'],
              onChanged: (_) => c.clearError('soDienThoai'),
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Mật khẩu',
              type: AppTextInputType.password,
              controller: c.matKhau,
              hint: 'Tối thiểu $kMinPasswordLength ký tự',
              required: true,
              requiredMessage: 'Vui lòng nhập mật khẩu',
              minPasswordLength: kMinPasswordLength,
              maxPasswordLength: kMaxPasswordLength,
              enabled: !c.isSaving,
              errorText: c.errors['matKhau'],
              onChanged: (_) => c.clearError('matKhau'),
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Xác nhận mật khẩu',
              type: AppTextInputType.password,
              controller: c.xacNhanMatKhau,
              hint: 'Nhập lại mật khẩu',
              required: true,
              requiredMessage: 'Vui lòng xác nhận mật khẩu',
              enabled: !c.isSaving,
              errorText: c.errors['xacNhan'],
              onChanged: (_) => c.clearError('xacNhan'),
              // So khớp với mật khẩu ở ô trên, giống rule bên _validate().
              validator: (raw) => raw != c.matKhau.text.trim()
                  ? 'Mật khẩu xác nhận không khớp'
                  : null,
            ),
            _passwordHints(),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Email',
              type: AppTextInputType.email,
              controller: c.email,
              hint: 'Nhập địa chỉ email',
              required: true,
              requiredMessage: 'Vui lòng nhập email',
              enabled: !c.isSaving,
              errorText: c.errors['email'],
              onChanged: (_) => c.clearError('email'),
            ),
            const SizedBox(height: 14),
            _vaiTroField(context),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trạng thái'),
              subtitle: Text(c.trangThai ? 'Hoạt động' : 'Khóa'),
              value: c.trangThai,
              onChanged: c.isSaving ? null : c.setTrangThai,
            ),
            const SizedBox(height: 8),
            _mauSacField(context),
            if (c.formError != null) ...[
              const SizedBox(height: 12),
              Text(
                c.formError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }
}
