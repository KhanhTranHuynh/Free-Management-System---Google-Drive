import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/danh_muc_khach_hang_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';
import '../../utils/mau_sac_util.dart';

final RegExp _maDanhMucRegex = RegExp(r'^[a-zA-Z0-9_]+$');

/// Mở modal "Thêm danh mục khách hàng".
/// Trả về `true` nếu tạo thành công (View danh sách gọi `_taiLai()`),
/// `null` nếu người dùng hủy.
///
/// [idStudioLocal]: truyền id studio local nếu có, để sinh mã đúng phạm vi
/// (khớp tham số bên bản React `sinhMaDanhMuc`).
Future<bool?> showAddDanhMucKhachHangModal(
  BuildContext context, {
  String? idStudioLocal,
}) async {
  final controller = _AddDanhMucController(
    DanhMucKhachHangApi(ApiRequestManager.instance),
  );

  final result = await showAppModal<bool>(
    context,
    title: 'Thêm danh mục khách hàng',
    type: AppModalType.bottomSheet,
    closeOnBackdropClick: false, // form nhập dở -> chạm ra ngoài chỉ rung
    // Truyền idStudioLocal xuống body để tự gọi sinhMa() trong initState —
    // đảm bảo lúc gọi API thì AppTextInput đã chắc chắn mount & đang lắng
    // nghe controller, tránh race condition khi gọi API trước lúc mở modal.
    builder: (_) =>
        _AddDanhMucBody(c: controller, idStudioLocal: idStudioLocal),
    footerBuilder: (_) => _AddDanhMucFooter(c: controller),
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
class _AddDanhMucController extends ChangeNotifier {
  _AddDanhMucController(this._api);

  final DanhMucKhachHangApi _api;

  final maDanhMuc = TextEditingController();
  final tenHienThi = TextEditingController();
  final moTa = TextEditingController();

  bool trangThai = true; // mặc định Hoạt động

  // Màu hiển thị: ẨN khỏi UI (giống bản React đang comment ColorPicker),
  // nhưng vẫn giữ giá trị mặc định để gửi lên payload cho đồng bộ dữ liệu.
  final String mauSac = kMauSacMacDinh;

  bool dangSinhMa = false;
  bool _daSinhMa = false; // chặn gọi lại nhiều lần nếu initState chạy lại
  bool isSaving = false;
  String? formError;
  final Map<String, String> errors = {};

  Future<void> sinhMa({String? idStudioLocal}) async {
    if (_daSinhMa) return;
    _daSinhMa = true;

    dangSinhMa = true;
    notifyListeners();
    try {
      final body = await _api.sinhMa(idStudioLocal: idStudioLocal);
      debugPrint('[sinhMa] body nhận được: $body'); // <-- thêm dòng này

      final ma = body['data']?.toString();
      debugPrint('[sinhMa] ma parse được: $ma'); // <-- thêm dòng này

      if (ma != null && ma.isNotEmpty) {
        maDanhMuc.text = ma;
        debugPrint(
            '[sinhMa] maDanhMuc.text sau khi gán: ${maDanhMuc.text}'); // <-- thêm dòng này
        errors.remove('maDanhMuc');
      }
    } catch (e, st) {
      debugPrint('Lỗi sinh mã danh mục: $e');
      debugPrint(
          '$st'); // <-- thêm dòng này để xem stack trace nếu có exception bị nuốt
    } finally {
      dangSinhMa = false;
      notifyListeners();
    }
  }

  void clearError(String key) {
    errors.remove(key);
    formError = null;
    notifyListeners();
  }

  void setTrangThai(bool v) {
    trangThai = v;
    notifyListeners();
  }

  bool _validate() {
    errors.clear();
    final ma = maDanhMuc.text.trim();
    final ten = tenHienThi.text.trim();

    if (ma.isEmpty) {
      errors['maDanhMuc'] = 'Vui lòng nhập mã danh mục';
    } else if (!_maDanhMucRegex.hasMatch(ma)) {
      errors['maDanhMuc'] =
          'Mã danh mục chỉ gồm chữ, số và dấu gạch dưới, không khoảng trắng';
    }

    if (ten.isEmpty) errors['tenHienThi'] = 'Vui lòng nhập tên danh mục';

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

    final payload = <String, dynamic>{
      'ma_danh_muc': maDanhMuc.text.trim(),
      'ten_hien_thi': tenHienThi.text.trim(),
      'mo_ta': moTa.text.trim(),
      'dang_hoat_dong': trangThai,
      'mau_sac': mauSac.trim().isEmpty ? null : mauSac.trim(),
    };

    try {
      await _api.taoMoi(payload);
      return true;
    } on ApiException {
      // Toast lỗi đã được hiển thị ở tầng API (notifyApiByCode).
      return false;
    } catch (_) {
      formError = 'Thêm danh mục thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    maDanhMuc.dispose();
    tenHienThi.dispose();
    moTa.dispose();
    super.dispose();
  }
}

// ============================================================
// FOOTER: Hủy / Lưu
// ============================================================
class _AddDanhMucFooter extends StatelessWidget {
  const _AddDanhMucFooter({required this.c});
  final _AddDanhMucController c;

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
// StatefulWidget để tự gọi c.sinhMa() trong initState — đảm bảo
// AppTextInput/ListenableBuilder đã chắc chắn mount trước khi gọi API,
// tránh trường hợp mã trả về bị "trôi mất" do gọi API quá sớm từ bên
// ngoài modal.
// ============================================================
class _AddDanhMucBody extends StatefulWidget {
  const _AddDanhMucBody({required this.c, this.idStudioLocal});

  final _AddDanhMucController c;
  final String? idStudioLocal;

  @override
  State<_AddDanhMucBody> createState() => _AddDanhMucBodyState();
}

class _AddDanhMucBodyState extends State<_AddDanhMucBody> {
  @override
  void initState() {
    super.initState();
    // Gọi sau khi widget đã mount xong (post frame) để chắc chắn
    // ListenableBuilder bên dưới đã kịp subscribe trước khi API trả về.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.c.sinhMa(idStudioLocal: widget.idStudioLocal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextInput(
              label: 'Mã danh mục',
              type: AppTextInputType.text,
              controller: c.maDanhMuc,
              hint: c.dangSinhMa
                  ? 'Đang sinh mã...'
                  : 'Vd: vip, than_thiet, moi...',
              required: true,
              requiredMessage: 'Vui lòng nhập mã danh mục',
              // Khóa ô trong lúc đang tự sinh mã, tránh người dùng gõ đè
              // rồi bị ghi đè lại khi API trả về.
              enabled: !c.isSaving && !c.dangSinhMa,
              errorText: c.errors['maDanhMuc'],
              onChanged: (_) => c.clearError('maDanhMuc'),
            ),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trạng thái'),
              subtitle: Text(c.trangThai ? 'Hoạt động' : 'Khóa'),
              value: c.trangThai,
              onChanged: c.isSaving ? null : c.setTrangThai,
            ),
            // Phần "Màu hiển thị" đã ẩn khỏi form (giữ giá trị mặc định
            // kMauSacMacDinh gửi ngầm trong payload) — khớp bản React
            // đang comment khối ColorPicker.
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
