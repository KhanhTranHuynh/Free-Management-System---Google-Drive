import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';

const int kMinPasswordLengthKh = 6;
const int kMaxPasswordLengthKh = 50;

final RegExp _phoneRegexKh = RegExp(r'^0\d{9}$');
final RegExp _emailRegexKh = RegExp(r'^\S+@\S+\.\S+$');

Future<bool?> showAddTaiKhoanKhachHangModal(
  BuildContext context, {
  required List<Map<String, dynamic>> danhMucOptions,
}) async {
  final controller = _AddTaiKhoanKhachHangController(
    TaiKhoanKhachHangApi(ApiRequestManager.instance),
  );

  final result = await showAppModal<bool>(
    context,
    title: 'Thêm khách hàng',
    type: AppModalType.bottomSheet,
    closeOnBackdropClick: false, // form nhập dở -> chạm ra ngoài chỉ rung
    builder: (_) => _AddTaiKhoanKhachHangBody(
      c: controller,
      danhMucOptions: danhMucOptions,
    ),
    footerBuilder: (_) => _AddTaiKhoanKhachHangFooter(c: controller),
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
class _AddTaiKhoanKhachHangController extends ChangeNotifier {
  _AddTaiKhoanKhachHangController(this._api);

  final TaiKhoanKhachHangApi _api;

  final soDienThoai = TextEditingController();
  final matKhau = TextEditingController();
  final hoTen = TextEditingController();
  final email = TextEditingController();
  final soDienThoaiLienHe = TextEditingController();
  final diaChi = TextEditingController();
  final ghiChu = TextEditingController();

  String? danhMucKhachHangId;
  bool trangThai = true; // mặc định Hoạt động
  bool choPhepDangNhapPortal = true; // mặc định Có

  bool isSaving = false;
  String? formError;
  final Map<String, String> errors = {};

  void clearError(String key) {
    errors.remove(key);
    formError = null;
    notifyListeners();
  }

  void setDanhMuc(String? id) {
    danhMucKhachHangId = id;
    errors.remove('danhMuc');
    notifyListeners();
  }

  void setTrangThai(bool? v) {
    if (v == null) return;
    trangThai = v;
    notifyListeners();
  }

  void setChoPhepPortal(bool? v) {
    if (v == null) return;
    choPhepDangNhapPortal = v;
    notifyListeners();
  }

  bool _validate() {
    errors.clear();
    final sdt = soDienThoai.text.trim();
    final mk = matKhau.text.trim();
    final ten = hoTen.text.trim();
    final mail = email.text.trim();
    final diaChiText = diaChi.text.trim();
    final ghiChuText = ghiChu.text.trim();

    if (sdt.isEmpty) {
      errors['soDienThoai'] = 'Vui lòng nhập số điện thoại đăng nhập';
    } else if (!_phoneRegexKh.hasMatch(sdt)) {
      errors['soDienThoai'] = 'Số điện thoại không hợp lệ';
    }

    if (danhMucKhachHangId == null) {
      errors['danhMuc'] = 'Vui lòng chọn danh mục khách hàng';
    }

    if (mk.isEmpty) {
      errors['matKhau'] = 'Vui lòng nhập mật khẩu';
    } else if (mk.length < kMinPasswordLengthKh) {
      errors['matKhau'] =
          'Mật khẩu phải có ít nhất $kMinPasswordLengthKh ký tự';
    } else if (mk.length > kMaxPasswordLengthKh) {
      errors['matKhau'] = 'Mật khẩu không được quá $kMaxPasswordLengthKh ký tự';
    }

    if (ten.isEmpty) {
      errors['hoTen'] = 'Vui lòng nhập họ tên';
    } else if (ten.length > 255) {
      errors['hoTen'] = 'Họ tên tối đa 255 ký tự';
    }

    if (mail.isEmpty || !_emailRegexKh.hasMatch(mail)) {
      errors['email'] = 'Email không hợp lệ';
    }

    if (diaChiText.length > 500) {
      errors['diaChi'] = 'Địa chỉ tối đa 500 ký tự';
    }

    if (ghiChuText.length > 2000) {
      errors['ghiChu'] = 'Ghi chú tối đa 2000 ký tự';
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

    // KHÔNG gửi id_studio_local — BE tự lấy từ JWT của nhân viên đang gọi,
    // giống payload bên bản React (xem controller.taoKhachHang).
    final payload = <String, dynamic>{
      'so_dien_thoai': soDienThoai.text.trim(),
      'mat_khau': matKhau.text.trim(),
      'ho_ten': hoTen.text.trim(),
      'email': email.text.trim(),
      'so_dien_thoai_lien_he': soDienThoaiLienHe.text.trim().isEmpty
          ? null
          : soDienThoaiLienHe.text.trim(),
      'dia_chi': diaChi.text.trim().isEmpty ? null : diaChi.text.trim(),
      'ghi_chu': ghiChu.text.trim().isEmpty ? null : ghiChu.text.trim(),
      'danh_muc_khach_hang_id': danhMucKhachHangId,
      'trang_thai': trangThai,
      'cho_phep_dang_nhap_portal': choPhepDangNhapPortal,
    };

    try {
      await _api.taoMoi(payload);
      return true;
    } on ApiException {
      // Toast lỗi đã được hiển thị ở tầng API (notifyApiByCode).
      return false;
    } catch (_) {
      formError = 'Thêm khách hàng thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    soDienThoai.dispose();
    matKhau.dispose();
    hoTen.dispose();
    email.dispose();
    soDienThoaiLienHe.dispose();
    diaChi.dispose();
    ghiChu.dispose();
    super.dispose();
  }
}

// ============================================================
// FOOTER: Hủy / Lưu
// ============================================================
class _AddTaiKhoanKhachHangFooter extends StatelessWidget {
  const _AddTaiKhoanKhachHangFooter({required this.c});
  final _AddTaiKhoanKhachHangController c;

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
class _AddTaiKhoanKhachHangBody extends StatelessWidget {
  const _AddTaiKhoanKhachHangBody({
    required this.c,
    required this.danhMucOptions,
  });

  final _AddTaiKhoanKhachHangController c;
  final List<Map<String, dynamic>> danhMucOptions;

  Widget _danhMucField(BuildContext context) {
    final theme = Theme.of(context);
    final validIds = <String?>{
      null,
      ...danhMucOptions.map((dm) => dm['id_danh_muc_khach_hang']?.toString()),
    };
    final currentValue =
        validIds.contains(c.danhMucKhachHangId) ? c.danhMucKhachHangId : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey('them-danh-muc-${danhMucOptions.length}-$currentValue'),
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Danh mục khách hàng *',
        border: const OutlineInputBorder(),
        errorText: c.errors['danhMuc'],
      ),
      items: [
        for (final dm in danhMucOptions)
          DropdownMenuItem(
            value: dm['id_danh_muc_khach_hang']?.toString(),
            child: Text(dm['ten_hien_thi']?.toString() ?? ''),
          ),
      ],
      onChanged: c.isSaving ? null : c.setDanhMuc,
      validator: (_) => theme.brightness == null ? null : null, // no-op
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
            AppTextInput(
              label: 'Số điện thoại đăng nhập',
              type: AppTextInputType.phone,
              controller: c.soDienThoai,
              hint: 'Số dùng để khách đăng nhập',
              required: true,
              requiredMessage: 'Vui lòng nhập số điện thoại đăng nhập',
              enabled: !c.isSaving,
              errorText: c.errors['soDienThoai'],
              onChanged: (_) => c.clearError('soDienThoai'),
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Mật khẩu',
              type: AppTextInputType.password,
              controller: c.matKhau,
              hint: 'Tối thiểu $kMinPasswordLengthKh ký tự',
              required: true,
              requiredMessage: 'Vui lòng nhập mật khẩu',
              minPasswordLength: kMinPasswordLengthKh,
              maxPasswordLength: kMaxPasswordLengthKh,
              enabled: !c.isSaving,
              errorText: c.errors['matKhau'],
              onChanged: (_) => c.clearError('matKhau'),
            ),
            const SizedBox(height: 14),
            // "Họ tên" là loại `text` -> AppTextInput giữ autocorrect/
            // enableSuggestions bật, tránh bug mất chữ khi gõ tiếng Việt.
            AppTextInput(
              label: 'Họ tên',
              type: AppTextInputType.text,
              controller: c.hoTen,
              hint: 'Vd: Nguyễn Văn A',
              required: true,
              requiredMessage: 'Vui lòng nhập họ tên',
              enabled: !c.isSaving,
              errorText: c.errors['hoTen'],
              onChanged: (_) => c.clearError('hoTen'),
            ),
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
            AppTextInput(
              label: 'Số điện thoại liên hệ',
              type: AppTextInputType.phone,
              controller: c.soDienThoaiLienHe,
              hint: 'Có thể khác số đăng nhập (không bắt buộc)',
              enabled: !c.isSaving,
              onChanged: (_) => c.clearError('soDienThoaiLienHe'),
            ),
            const SizedBox(height: 14),
            _danhMucField(context),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Địa chỉ',
              type: AppTextInputType.text,
              controller: c.diaChi,
              hint: 'Không bắt buộc',
              enabled: !c.isSaving,
              errorText: c.errors['diaChi'],
              onChanged: (_) => c.clearError('diaChi'),
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Ghi chú',
              type: AppTextInputType.text,
              controller: c.ghiChu,
              hint: 'Ghi chú nội bộ về khách hàng này (không bắt buộc)',
              enabled: !c.isSaving,
              errorText: c.errors['ghiChu'],
              onChanged: (_) => c.clearError('ghiChu'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<bool>(
              initialValue: c.trangThai,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trạng thái',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: true, child: Text('Hoạt động')),
                DropdownMenuItem(value: false, child: Text('Khóa')),
              ],
              onChanged: c.isSaving ? null : c.setTrangThai,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<bool>(
              initialValue: c.choPhepDangNhapPortal,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cho phép đăng nhập portal',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: true, child: Text('Có')),
                DropdownMenuItem(value: false, child: Text('Không')),
              ],
              onChanged: c.isSaving ? null : c.setChoPhepPortal,
            ),
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
