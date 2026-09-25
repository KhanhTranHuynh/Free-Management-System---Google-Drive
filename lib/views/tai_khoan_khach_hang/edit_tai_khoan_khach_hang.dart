import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';

/// Chuẩn hoá dữ liệu khách hàng (Map thô từ API/list) về đúng shape form sửa.
class _EditFormData {
  _EditFormData({
    required this.hoTen,
    required this.soDienThoai,
    required this.email,
    required this.soDienThoaiLienHe,
    required this.diaChi,
    required this.ghiChu,
    required this.danhMucKhachHangId,
    required this.trangThai,
    required this.choPhepDangNhapPortal,
  });

  factory _EditFormData.fromItem(Map<String, dynamic> item) {
    return _EditFormData(
      hoTen: item['ho_ten']?.toString() ?? '',
      soDienThoai: (item['so_dien_thoai_dang_nhap'] ?? item['so_dien_thoai'])
              ?.toString() ??
          '',
      email: item['email']?.toString() ?? '',
      soDienThoaiLienHe: item['so_dien_thoai_lien_he']?.toString() ?? '',
      diaChi: item['dia_chi']?.toString() ?? '',
      ghiChu: item['ghi_chu']?.toString() ?? '',
      danhMucKhachHangId: item['danh_muc_khach_hang_id']?.toString(),
      trangThai: item['trang_thai'] == true,
      choPhepDangNhapPortal: item['cho_phep_dang_nhap_portal'] == true,
    );
  }

  final String hoTen;
  final String soDienThoai;
  final String email;
  final String soDienThoaiLienHe;
  final String diaChi;
  final String ghiChu;
  final String? danhMucKhachHangId;
  final bool trangThai;
  final bool choPhepDangNhapPortal;
}

/// Mở modal "Cập nhật khách hàng".
/// Trả về `true` nếu cập nhật thành công (nơi gọi tự reload), `null` nếu
/// người dùng hủy.
///
/// [khachHang]: bản ghi khách hàng đang sửa (Map thô, như trong danh sách).
/// [danhMucOptions]: danh sách danh mục đã tải sẵn ở View danh sách.
Future<bool?> showEditTaiKhoanKhachHangModal(
  BuildContext context, {
  required Map<String, dynamic> khachHang,
  required List<Map<String, dynamic>> danhMucOptions,
}) async {
  final controller = _EditTaiKhoanKhachHangController(
    TaiKhoanKhachHangApi(ApiRequestManager.instance),
    khachHang: khachHang,
  );

  final result = await showAppModal<bool>(
    context,
    title: 'Cập nhật khách hàng',
    type: AppModalType.bottomSheet,
    closeOnBackdropClick: false,
    builder: (_) => _EditTaiKhoanKhachHangBody(
      c: controller,
      danhMucOptions: danhMucOptions,
    ),
    footerBuilder: (_) => _EditTaiKhoanKhachHangFooter(c: controller),
  );

  Future.delayed(const Duration(milliseconds: 500), controller.dispose);
  return result;
}

// ============================================================
// CONTROLLER
// ============================================================
class _EditTaiKhoanKhachHangController extends ChangeNotifier {
  _EditTaiKhoanKhachHangController(this._api, {required this.khachHang})
      : hoTen = TextEditingController(
            text: _EditFormData.fromItem(khachHang).hoTen),
        soDienThoaiLienHe = TextEditingController(
            text: _EditFormData.fromItem(khachHang).soDienThoaiLienHe),
        diaChi = TextEditingController(
            text: _EditFormData.fromItem(khachHang).diaChi),
        ghiChu = TextEditingController(
            text: _EditFormData.fromItem(khachHang).ghiChu) {
    final form = _EditFormData.fromItem(khachHang);
    soDienThoai = form.soDienThoai;
    email = form.email;
    danhMucKhachHangId = form.danhMucKhachHangId;
    trangThai = form.trangThai;
    choPhepDangNhapPortal = form.choPhepDangNhapPortal;
  }

  final TaiKhoanKhachHangApi _api;
  final Map<String, dynamic> khachHang;

  // Chỉ các trường này cho phép sửa qua text input.
  final TextEditingController hoTen;
  final TextEditingController soDienThoaiLienHe;
  final TextEditingController diaChi;
  final TextEditingController ghiChu;

  // Số điện thoại đăng nhập / email chỉ hiển thị, không cho sửa (giống
  // readonly+disabled bên bản React) — không cần TextEditingController riêng.
  late String soDienThoai;
  late String email;

  String? danhMucKhachHangId;
  late bool trangThai;
  late bool choPhepDangNhapPortal;

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
    final ten = hoTen.text.trim();
    final diaChiText = diaChi.text.trim();
    final ghiChuText = ghiChu.text.trim();

    if (ten.isEmpty) {
      errors['hoTen'] = 'Vui lòng nhập họ tên';
    } else if (ten.length > 255) {
      errors['hoTen'] = 'Họ tên tối đa 255 ký tự';
    }

    if (danhMucKhachHangId == null) {
      errors['danhMuc'] = 'Vui lòng chọn danh mục khách hàng';
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

  Future<bool> submit() async {
    if (isSaving) return false;
    if (!_validate()) return false;

    isSaving = true;
    formError = null;
    notifyListeners();

    final payload = <String, dynamic>{
      'id': khachHang['id'] ?? khachHang['id_tai_khoan_khach_hang'],
      'ho_ten': hoTen.text.trim(),
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
      // TODO: xác nhận đúng tên field id thật (đang giả định 'id', fallback
      // 'id_tai_khoan_khach_hang').
      await _api.capNhat(payload);
      return true;
    } on ApiException {
      return false; // toast lỗi đã hiển thị ở tầng API
    } catch (_) {
      formError = 'Cập nhật khách hàng thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    hoTen.dispose();
    soDienThoaiLienHe.dispose();
    diaChi.dispose();
    ghiChu.dispose();
    super.dispose();
  }
}

// ============================================================
// FOOTER
// ============================================================
class _EditTaiKhoanKhachHangFooter extends StatelessWidget {
  const _EditTaiKhoanKhachHangFooter({required this.c});
  final _EditTaiKhoanKhachHangController c;

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
class _EditTaiKhoanKhachHangBody extends StatelessWidget {
  const _EditTaiKhoanKhachHangBody({
    required this.c,
    required this.danhMucOptions,
  });

  final _EditTaiKhoanKhachHangController c;
  final List<Map<String, dynamic>> danhMucOptions;

  Widget _danhMucField(BuildContext context) {
    final validIds = <String?>{
      null,
      ...danhMucOptions.map((dm) => dm['id_danh_muc_khach_hang']?.toString()),
    };
    final currentValue =
        validIds.contains(c.danhMucKhachHangId) ? c.danhMucKhachHangId : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey('sua-danh-muc-${danhMucOptions.length}-$currentValue'),
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
            // Số điện thoại đăng nhập / Email: chỉ xem, không cho sửa —
            // giống `readonly disabled` bên bản React.
            AppTextInput(
              label: 'Số điện thoại đăng nhập',
              type: AppTextInputType.phone,
              initialValue: c.soDienThoai,
              enabled: false,
              readOnly: true,
            ),
            const SizedBox(height: 14),
            AppTextInput(
              label: 'Email',
              type: AppTextInputType.email,
              initialValue: c.email,
              enabled: false,
              readOnly: true,
            ),
            const SizedBox(height: 14),
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
