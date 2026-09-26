import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/nhan_vien_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';
import '../../utils/mau_sac_util.dart';

/// Chuẩn hoá dữ liệu nhân viên (Map thô từ API/list) về đúng shape form sửa
/// — tương đương `mapNhanVienToForm` bên bản React.
class _EditFormData {
  _EditFormData({
    required this.hoTen,
    required this.soDienThoai,
    required this.email,
    required this.vaiTro,
    required this.trangThai,
    required this.mauSac,
  });

  factory _EditFormData.fromItem(Map<String, dynamic> item) {
    return _EditFormData(
      hoTen: item['ho_ten']?.toString() ?? '',
      soDienThoai: item['so_dien_thoai']?.toString() ?? '',
      email: item['email']?.toString() ?? '',
      vaiTro: _parseVaiTro(item['vai_tro']),
      trangThai: item['trang_thai'] == true,
      mauSac: item['mau_sac']?.toString() ?? kMauSacMacDinh,
    );
  }

  /// FIX: bản cũ chỉ xử lý được `vai_tro` dạng List (String đơn hoặc Map
  /// đơn sẽ bị coi là rỗng) -> mở modal Sửa nhưng không tick sẵn vai trò
  /// nào dù nhân viên đã có. Giờ xử lý đủ 3 dạng dữ liệu có thể gặp,
  /// đồng nhất với cách `_laChuStudio` bên list view đang xử lý.
  static List<String> _parseVaiTro(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .map((v) {
            if (v is Map) {
              return (v['value'] ?? v['ma_vai_tro'] ?? v['id_vai_tro'])
                  ?.toString();
            }
            return v?.toString();
          })
          .whereType<String>()
          .toList();
    }

    if (raw is Map) {
      final ma =
          (raw['value'] ?? raw['ma_vai_tro'] ?? raw['id_vai_tro'])?.toString();
      return ma == null || ma.isEmpty ? const [] : [ma];
    }

    // Trường hợp BE trả String đơn, vd "nhan_vien" thay vì ["nhan_vien"].
    final s = raw.toString();
    return s.isEmpty ? const [] : [s];
  }

  final String hoTen;
  final String soDienThoai;
  final String email;
  final List<String> vaiTro;
  final bool trangThai;
  final String mauSac;
}

/// Mở modal "Cập nhật nhân viên".
/// Trả về `true` nếu cập nhật thành công (nơi gọi tự `reload()`), `null` nếu
/// người dùng hủy.
///
/// [nhanVien]: bản ghi nhân viên đang sửa (Map thô, như trong danh sách).
/// [vaiTroOptions]: danh sách vai trò đã tải sẵn ở View danh sách.
Future<bool?> showEditNhanVienModal(
  BuildContext context, {
  required Map<String, dynamic> nhanVien,
  required List<Map<String, dynamic>> vaiTroOptions,
}) async {
  final controller = _EditNhanVienController(
    NhanVienApi(ApiRequestManager.instance),
    nhanVien: nhanVien,
  );

  final result = await showAppModal<bool>(
    context,
    title: 'Cập nhật nhân viên',
    type: AppModalType.bottomSheet,
    closeOnBackdropClick: false,
    builder: (_) => _EditNhanVienBody(
      c: controller,
      vaiTroOptions: vaiTroOptions,
    ),
    footerBuilder: (_) => _EditNhanVienFooter(c: controller),
  );

  Future.delayed(const Duration(milliseconds: 500), controller.dispose);
  return result;
}

// ============================================================
// CONTROLLER
// ============================================================
class _EditNhanVienController extends ChangeNotifier {
  /// Factory tính `_EditFormData.fromItem(nhanVien)` đúng MỘT lần rồi truyền
  /// vào constructor thật (`._`) — bản trước tính 2 lần (một ở initializer
  /// list cho `hoTen`, một ở body cho các field còn lại).
  factory _EditNhanVienController(
    NhanVienApi api, {
    required Map<String, dynamic> nhanVien,
  }) {
    final form = _EditFormData.fromItem(nhanVien);
    return _EditNhanVienController._(api, nhanVien: nhanVien, form: form);
  }

  _EditNhanVienController._(
    this._api, {
    required this.nhanVien,
    required _EditFormData form,
  })  : hoTen = TextEditingController(text: form.hoTen),
        soDienThoai = form.soDienThoai,
        email = form.email,
        vaiTro = List<String>.from(form.vaiTro),
        trangThai = form.trangThai,
        mauSac = form.mauSac;

  final NhanVienApi _api;
  final Map<String, dynamic> nhanVien;

  // Họ tên là trường duy nhất cho phép sửa qua text input.
  final TextEditingController hoTen;

  // Số điện thoại / email chỉ hiển thị, không cho sửa (giống readonly+disabled
  // bên bản React) — không cần TextEditingController riêng.
  final String soDienThoai;
  final String email;

  List<String> vaiTro;
  bool trangThai;
  String mauSac;

  bool isSaving = false;
  String? formError;
  final Map<String, String> errors = {};

  void clearError(String key) {
    errors.remove(key);
    formError = null;
    notifyListeners();
  }

  void toggleVaiTro(String ma) {
    vaiTro.contains(ma) ? vaiTro.remove(ma) : vaiTro.add(ma);
    errors.remove('vaiTro');
    notifyListeners();
  }

  void setTrangThai(bool? v) {
    if (v == null) return;
    trangThai = v;
    notifyListeners();
  }

  /// Nhận hex từ `MauSacGoiYPicker` (preset hoặc bánh xe tự do) — cùng một
  /// điểm vào duy nhất, đồng bộ với modal Thêm nhân viên / Sửa thông tin.
  void setMauSac(String hex) {
    mauSac = hex;
    errors.remove('mauSac');
    notifyListeners();
  }

  bool _validate() {
    errors.clear();
    final ten = hoTen.text.trim();

    if (ten.isEmpty) errors['hoTen'] = 'Vui lòng nhập họ tên';
    if (vaiTro.isEmpty) errors['vaiTro'] = 'Vui lòng chọn ít nhất một vai trò';
    if (mauSac.isNotEmpty && !isHexMauSacHopLe(mauSac.trim())) {
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

    final payload = <String, dynamic>{
      'id_tai_khoan_nhan_vien':
          nhanVien['id'] ?? nhanVien['id_tai_khoan_nhan_vien'],
      'ho_ten': hoTen.text.trim(),
      'vai_tro': List<String>.from(vaiTro),
      'trang_thai': trangThai,
      'mau_sac': mauSac.trim().isEmpty ? null : mauSac.trim(),
    };

    try {
      // TODO: xác nhận đúng tên hàm update bên NhanVienApi (đang giả định
      // là `capNhat`, tương ứng `NhanVienApi.capNhat` bên bản React).
      await _api.capNhat(payload);
      return true;
    } on ApiException {
      return false; // toast lỗi đã hiển thị ở tầng API
    } catch (_) {
      formError = 'Cập nhật nhân viên thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    hoTen.dispose();
    super.dispose();
  }
}

// ============================================================
// FOOTER
// ============================================================
class _EditNhanVienFooter extends StatelessWidget {
  const _EditNhanVienFooter({required this.c});
  final _EditNhanVienController c;

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
class _EditNhanVienBody extends StatelessWidget {
  const _EditNhanVienBody({
    required this.c,
    required this.vaiTroOptions,
  });

  final _EditNhanVienController c;
  final List<Map<String, dynamic>> vaiTroOptions;

  Widget _trangThaiField(BuildContext context) {
    return DropdownButtonFormField<bool>(
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
    );
  }

  Widget _vaiTroField(BuildContext context) {
    final theme = Theme.of(context);
    // Loại chủ studio khỏi options — không cho gán/gỡ vai trò chủ studio
    // qua modal sửa nhân viên thường.
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
        // Đồng bộ với modal Thêm nhân viên / Sửa thông tin cá nhân: dùng
        // chung `MauSacGoiYPicker` (bảng preset + nút "+" mở bánh xe màu
        // tự do) thay vì tự vẽ lại bảng màu riêng như bản trước.
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
            // Trường duy nhất cho sửa trực tiếp -> loại `text`, giữ
            // autocorrect/enableSuggestions bật để không bị mất chữ tiếng Việt.
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
            _trangThaiField(context),
            const SizedBox(height: 14),
            // Số điện thoại / Email: chỉ xem, không cho sửa — giống
            // `readonly disabled` bên bản React (không có onChanged thật).
            AppTextInput(
              label: 'Số điện thoại',
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
            _vaiTroField(context),
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
