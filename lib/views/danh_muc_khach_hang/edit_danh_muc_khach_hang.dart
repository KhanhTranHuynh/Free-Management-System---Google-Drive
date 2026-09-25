import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/danh_muc_khach_hang_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';

const List<String> _mauSacGoiY = [
  '#3B82F6',
  '#10B981',
  '#F59E0B',
  '#EF4444',
  '#8B5CF6',
  '#EC4899',
  '#14B8A6',
  '#64748B',
];

final RegExp _hexRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');

Color _hexToColor(String hex) =>
    Color(int.parse('FF${hex.substring(1)}', radix: 16));

/// Mở modal "Sửa danh mục khách hàng".
/// Trả về `true` nếu cập nhật thành công (nơi gọi tự `reload()`), `null`
/// nếu người dùng hủy.
Future<bool?> showEditDanhMucKhachHangModal(
  BuildContext context, {
  required Map<String, dynamic> danhMuc,
}) async {
  final controller = _EditDanhMucController(
    DanhMucKhachHangApi(ApiRequestManager.instance),
    danhMuc: danhMuc,
  );

  final result = await showAppModal<bool>(
    context,
    title: 'Sửa danh mục khách hàng',
    type: AppModalType.bottomSheet,
    closeOnBackdropClick: false,
    builder: (_) => _EditDanhMucBody(c: controller),
    footerBuilder: (_) => _EditDanhMucFooter(c: controller),
  );

  Future.delayed(const Duration(milliseconds: 500), controller.dispose);
  return result;
}

// ============================================================
// CONTROLLER
// ============================================================
class _EditDanhMucController extends ChangeNotifier {
  _EditDanhMucController(this._api, {required this.danhMuc})
      : tenHienThi =
            TextEditingController(text: danhMuc['ten_hien_thi']?.toString()),
        moTa = TextEditingController(text: danhMuc['mo_ta']?.toString()) {
    trangThai = danhMuc['dang_hoat_dong'] == true;
    mauSac = danhMuc['mau_sac']?.toString() ?? _mauSacGoiY.first;
  }

  final DanhMucKhachHangApi _api;
  final Map<String, dynamic> danhMuc;

  final TextEditingController tenHienThi;
  final TextEditingController moTa;

  late bool trangThai;
  late String mauSac;

  bool isSaving = false;
  String? formError;
  final Map<String, String> errors = {};

  void clearError(String key) {
    errors.remove(key);
    formError = null;
    notifyListeners();
  }

  void setTrangThai(bool? v) {
    if (v == null) return;
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
    final ten = tenHienThi.text.trim();

    if (ten.isEmpty) errors['tenHienThi'] = 'Vui lòng nhập tên danh mục';
    if (mauSac.isNotEmpty && !_hexRegex.hasMatch(mauSac.trim())) {
      errors['mauSac'] = 'Mã màu không hợp lệ';
    }

    notifyListeners();
    return errors.isEmpty;
  }

  Future<bool> submit() async {
    if (isSaving) return false;
    if (!_validate()) return false;

    isSaving = true;
    formError = null;
    notifyListeners();

    // TODO: xác nhận đúng tên field id (đang giả định 'id', fallback
    // 'id_danh_muc_khach_hang') và tên hàm update thật của DanhMucKhachHangApi.
    final payload = <String, dynamic>{
      'id': danhMuc['id'] ?? danhMuc['id_danh_muc_khach_hang'],
      'ten_hien_thi': tenHienThi.text.trim(),
      'mo_ta': moTa.text.trim(),
      'dang_hoat_dong': trangThai,
      'mau_sac': mauSac.trim().isEmpty ? null : mauSac.trim(),
    };

    try {
      await _api.capNhat(payload);
      return true;
    } on ApiException {
      return false; // toast lỗi đã hiển thị ở tầng API
    } catch (_) {
      formError = 'Cập nhật danh mục thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    tenHienThi.dispose();
    moTa.dispose();
    super.dispose();
  }
}

// ============================================================
// FOOTER
// ============================================================
class _EditDanhMucFooter extends StatelessWidget {
  const _EditDanhMucFooter({required this.c});
  final _EditDanhMucController c;

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
// BODY
// ============================================================
class _EditDanhMucBody extends StatelessWidget {
  const _EditDanhMucBody({required this.c});
  final _EditDanhMucController c;

  Widget _maDanhMucReadonly(BuildContext context) {
    final theme = Theme.of(context);
    final ma = c.danhMuc['ma_danh_muc']?.toString() ?? '--';
    return Row(
      children: [
        Text('Mã danh mục: ', style: theme.textTheme.labelLarge),
        Text(ma, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _mauSacField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Màu hiển thị', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in _mauSacGoiY)
              GestureDetector(
                onTap: c.isSaving ? null : () => c.setMauSac(hex),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.mauSac.toUpperCase() == hex
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: c.mauSac.toUpperCase() == hex
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
          ],
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
            _maDanhMucReadonly(context),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Tên danh mục',
              type: AppTextInputType.text,
              controller: c.tenHienThi,
              hint: 'Nhập tên danh mục',
              required: true,
              requiredMessage: 'Vui lòng nhập tên danh mục',
              enabled: !c.isSaving,
              errorText: c.errors['tenHienThi'],
              onChanged: (_) => c.clearError('tenHienThi'),
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Mô tả',
              type: AppTextInputType.text,
              controller: c.moTa,
              hint: 'Mô tả (không bắt buộc)',
              enabled: !c.isSaving,
              onChanged: (_) => c.clearError('moTa'),
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
