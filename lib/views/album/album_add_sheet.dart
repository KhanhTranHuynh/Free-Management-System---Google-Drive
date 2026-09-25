import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_api.dart';

/// Form Thêm album — ĐÃ nối API thật (`AlbumApi.taoMoi`).
///
/// FIX so với bản mẫu UI trước:
///  1. `_luu()` gọi thẳng `AlbumApi.taoMoi(payload)` thay vì
///     `Future.delayed` giả lập; bắt `ApiException` để hiện lỗi qua
///     SnackBar — khớp convention try/catch của `danhSach`/`taoMoi`/
///     `capNhat` (không dùng notifyApiByCode vì các method này throw,
///     không tự toast như `doiTrangThai`).
///  2. `khachHangDaChon` đọc đúng key `id_tai_khoan_khach_hang` — vì
///     `widget.khachHangOptions` là data thô từ
///     `TaiKhoanKhachHangApi.layDanhSach` (không phải cặp
///     `{label, value}` như bên `AlbumEditSheet`).
///  3. `ngay_chup` lưu dưới dạng ISO `yyyy-MM-dd` (BE cần định dạng này,
///     khớp cách `AlbumEditSheet`/`edit.jsx` xử lý field này), chỉ hiển
///     thị `d/M/yyyy` cho người dùng dễ đọc qua `_ngayChupHienThi`.
///  4. Thêm validate tối thiểu: tên album bắt buộc — khớp validate bên
///     `AlbumEditSheet`/`edit.jsx`.
///
/// Trả về data album vừa tạo (hoặc `true` nếu BE không trả `data`) qua
/// `Navigator.pop` khi tạo thành công, để `AlbumListView` biết mà tải lại
/// danh sách — khớp prop `onCreated` bên React.
class AlbumAddSheet extends StatefulWidget {
  const AlbumAddSheet({super.key, required this.khachHangOptions});

  final List<Map<String, dynamic>> khachHangOptions;

  @override
  State<AlbumAddSheet> createState() => _AlbumAddSheetState();
}

class _AlbumAddSheetState extends State<AlbumAddSheet> {
  final _api = AlbumApi(ApiRequestManager.instance);

  final _tenAlbumController = TextEditingController();
  final _ngayChupController = TextEditingController(); // hiển thị d/M/yyyy
  final _duongDanDriveController = TextEditingController();
  final _ghiChuController = TextEditingController();
  final _matKhauController = TextEditingController();

  Map<String, dynamic>? _khachHangDaChon;
  bool _choPhepTai = true;
  bool _choPhepTruyCapCongKhai = false;
  bool _dangLuu = false;
  String? _loiTenAlbum;

  // Ngày chụp lưu riêng dạng ISO (yyyy-MM-dd) để gửi API — tách khỏi
  // `_ngayChupController` vì controller chỉ dùng để HIỂN THỊ d/M/yyyy.
  DateTime? _ngayChupDaChon;

  @override
  void dispose() {
    _tenAlbumController.dispose();
    _ngayChupController.dispose();
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

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (!_validate()) return;

    setState(() => _dangLuu = true);
    try {
      final payload = <String, dynamic>{
        'ten_album': _tenAlbumController.text.trim(),
        'tai_khoan_khach_hang_id': _khachHangDaChon?['id_tai_khoan_khach_hang'],
        'ngay_chup':
            _ngayChupDaChon != null ? _isoDate(_ngayChupDaChon!) : null,
        'duong_dan_drive': _duongDanDriveController.text.trim().isEmpty
            ? null
            : _duongDanDriveController.text.trim(),
        'ghi_chu': _ghiChuController.text.trim().isEmpty
            ? null
            : _ghiChuController.text.trim(),
        'cho_phep_xem_khong_dang_nhap': _choPhepTruyCapCongKhai,
        'cho_phep_tai': _choPhepTai,
        'mat_khau_truy_cap': _matKhauController.text.trim().isEmpty
            ? null
            : _matKhauController.text.trim(),
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
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  Future<void> _chonNgayChup() async {
    final ket = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDate: _ngayChupDaChon ?? DateTime.now(),
    );
    if (ket == null) return;
    setState(() {
      _ngayChupDaChon = ket;
      _ngayChupController.text = '${ket.day}/${ket.month}/${ket.year}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thêm album', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _tenAlbumController,
              decoration: InputDecoration(
                labelText: 'Tên album',
                errorText: _loiTenAlbum,
              ),
              onChanged: (_) {
                if (_loiTenAlbum != null) setState(() => _loiTenAlbum = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ngayChupController,
              readOnly: true,
              onTap: _chonNgayChup,
              decoration: const InputDecoration(
                labelText: 'Ngày chụp',
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _khachHangDaChon,
              decoration: const InputDecoration(labelText: 'Khách hàng'),
              items: [
                for (final kh in widget.khachHangOptions)
                  DropdownMenuItem(
                    value: kh,
                    child: Text(kh['ho_ten']?.toString() ?? '--'),
                  ),
              ],
              onChanged: (v) => setState(() => _khachHangDaChon = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _duongDanDriveController,
              decoration: const InputDecoration(labelText: 'Đường dẫn Drive'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ghiChuController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            const SizedBox(height: 16),
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
            TextField(
              controller: _matKhauController,
              decoration: const InputDecoration(labelText: 'Mật khẩu truy cập'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _dangLuu ? null : _luu,
                child: _dangLuu
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
      ),
    );
  }
}
