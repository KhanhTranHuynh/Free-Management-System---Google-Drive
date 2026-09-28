import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_api.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật trong dự án.
import '../../configs/app_colors.dart';
import '../../components/app_date_picker.dart';
import '../../components/app_modal.dart';
// TODO: chỉnh lại đường dẫn/tên class/tham số cho khớp app_text_input.dart.
import '../../components/app_text_input.dart';

/// Mở modal "Thêm album" (showAppModal dạng bottom sheet).
///
/// Trả về data album vừa tạo (Map) hoặc `true` nếu BE không trả `data`
/// khi tạo thành công; trả về `null` nếu người dùng đóng modal không lưu.
/// => Nơi gọi chỉ cần kiểm tra `ket != null` để tải lại danh sách.
Future<Object?> showAddAlbumModal(
  BuildContext context, {
  required List<Map<String, dynamic>> khachHangOptions,
}) {
  final handle = _AlbumAddHandle();

  return showAppModal<Object?>(
    context,
    title: 'Thêm album',
    type: AppModalType.bottomSheet,
    // Form có dữ liệu nhập dở -> không đóng khi bấm nền (modal sẽ rung).
    closeOnBackdropClick: false,
    builder: (_) => _AlbumAddForm(
      khachHangOptions: khachHangOptions,
      handle: handle,
    ),
    footerBuilder: (ctx) => ValueListenableBuilder<bool>(
      valueListenable: handle.dangLuu,
      builder: (_, dangLuu, __) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: dangLuu ? null : () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Hủy'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: dangLuu ? null : () => handle.luu?.call(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: dangLuu
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cầu nối giữa phần thân (form) và chân (nút Hủy/Lưu) của modal — vì
/// showAppModal tách `builder` và `footerBuilder` thành 2 builder riêng.
class _AlbumAddHandle {
  final ValueNotifier<bool> dangLuu = ValueNotifier<bool>(false);
  Future<void> Function()? luu;
}

class _AlbumAddForm extends StatefulWidget {
  const _AlbumAddForm({
    required this.khachHangOptions,
    required this.handle,
  });

  final List<Map<String, dynamic>> khachHangOptions;
  final _AlbumAddHandle handle;

  @override
  State<_AlbumAddForm> createState() => _AlbumAddFormState();
}

class _AlbumAddFormState extends State<_AlbumAddForm> {
  final _api = AlbumApi(ApiRequestManager.instance);

  final _tenAlbumController = TextEditingController();
  final _duongDanDriveController = TextEditingController();
  final _ghiChuController = TextEditingController();
  final _matKhauController = TextEditingController();

  Map<String, dynamic>? _khachHangDaChon;
  bool _choPhepTai = true;
  bool _choPhepTruyCapCongKhai = false;
  String? _loiTenAlbum;

  // Ngày chụp lưu dạng ISO yyyy-MM-dd (đúng định dạng BE cần) — chính là
  // giá trị của DatePickerField.
  String? _ngayChupIso;

  @override
  void initState() {
    super.initState();
    widget.handle.luu = _luu;
  }

  @override
  void dispose() {
    widget.handle.luu = null;
    _tenAlbumController.dispose();
    _duongDanDriveController.dispose();
    _ghiChuController.dispose();
    _matKhauController.dispose();
    super.dispose();
  }

  void _thongBao(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validate() {
    final loiTen = _tenAlbumController.text.trim().isEmpty
        ? 'Vui lòng nhập tên album'
        : null;
    setState(() => _loiTenAlbum = loiTen);
    return loiTen == null;
  }

  String? _trimOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _luu() async {
    if (widget.handle.dangLuu.value) return;
    // Blur ô đang nhập dở (vd ô ngày) để giá trị kịp được commit.
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validate()) return;

    widget.handle.dangLuu.value = true;
    try {
      final payload = <String, dynamic>{
        'ten_album': _tenAlbumController.text.trim(),
        'tai_khoan_khach_hang_id': _khachHangDaChon?['id_tai_khoan_khach_hang'],
        'ngay_chup': _ngayChupIso,
        'duong_dan_drive': _trimOrNull(_duongDanDriveController),
        'ghi_chu': _trimOrNull(_ghiChuController),
        'cho_phep_xem_khong_dang_nhap': _choPhepTruyCapCongKhai,
        'cho_phep_tai': _choPhepTai,
        'mat_khau_truy_cap': _trimOrNull(_matKhauController),
      };

      final ket = await _api.taoMoi(payload);

      if (!mounted) return;
      _thongBao('Thêm album thành công');
      Navigator.of(context).pop(ket.isNotEmpty ? ket : true);
    } on ApiException catch (e) {
      _thongBao(e.message.isNotEmpty ? e.message : 'Thêm album thất bại');
    } catch (_) {
      _thongBao('Đã có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      widget.handle.dangLuu.value = false;
    }
  }

  InputDecoration _deco(String label, {String? errorText}) => InputDecoration(
        labelText: label,
        errorText: errorText,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final homNay = DateTime.now();
    final homNayIso =
        '${homNay.year.toString().padLeft(4, '0')}-${homNay.month.toString().padLeft(2, '0')}-${homNay.day.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextInput(
          controller: _tenAlbumController,
          label: 'Tên album *',
          errorText: _loiTenAlbum,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_loiTenAlbum != null) setState(() => _loiTenAlbum = null);
          },
        ),
        const SizedBox(height: 14),
        DatePickerField(
          label: 'Ngày chụp',
          value: _ngayChupIso,
          min: '2015-01-01',
          max: homNayIso,
          selectedColor: AppColors.primary,
          onChanged: (v) => setState(() => _ngayChupIso = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: _khachHangDaChon,
          isExpanded: true,
          decoration: _deco('Khách hàng'),
          items: [
            for (final kh in widget.khachHangOptions)
              DropdownMenuItem(
                value: kh,
                child: Text(
                  kh['ho_ten']?.toString() ?? '--',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => setState(() => _khachHangDaChon = v),
        ),
        const SizedBox(height: 14),
        AppTextInput(
          controller: _duongDanDriveController,
          label: 'Đường dẫn Drive',
        ),
        const SizedBox(height: 14),
        // TODO: AppTextInput chưa có tham số maxLines nên tạm dùng TextField
        // cho ô nhiều dòng. Khi thêm maxLines vào AppTextInput thì đổi lại.
        TextField(
          controller: _ghiChuController,
          maxLines: 2,
          decoration: _deco('Ghi chú'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Cho phép truy cập công khai'),
          value: _choPhepTruyCapCongKhai,
          onChanged: (v) => setState(() => _choPhepTruyCapCongKhai = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Cho phép tải ảnh'),
          value: _choPhepTai,
          onChanged: (v) => setState(() => _choPhepTai = v),
        ),
        const SizedBox(height: 8),
        AppTextInput(
          controller: _matKhauController,
          label: 'Mật khẩu truy cập',
        ),
      ],
    );
  }
}
