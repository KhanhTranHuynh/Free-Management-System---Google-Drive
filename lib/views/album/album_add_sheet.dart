import 'package:flutter/material.dart';

/// Form Thêm album — MẪU UI cho đẹp trang danh sách, chưa nối API thật.
/// Khi có endpoint/payload chính xác, chỉ cần thay nội dung trong `_luu()`.
///
/// Trả về `true` qua Navigator.pop khi "tạo thành công" để AlbumListView
/// biết mà tải lại danh sách — khớp prop `onCreated` bên React.
class AlbumAddSheet extends StatefulWidget {
  const AlbumAddSheet({super.key, required this.khachHangOptions});

  final List<Map<String, dynamic>> khachHangOptions;

  @override
  State<AlbumAddSheet> createState() => _AlbumAddSheetState();
}

class _AlbumAddSheetState extends State<AlbumAddSheet> {
  final _tenAlbumController = TextEditingController();
  final _ngayChupController = TextEditingController();
  final _duongDanDriveController = TextEditingController();
  final _ghiChuController = TextEditingController();
  final _matKhauController = TextEditingController();

  Map<String, dynamic>? _khachHangDaChon;
  bool _choPhepTai = true;
  bool _choPhepTruyCapCongKhai = false;
  bool _dangLuu = false;

  @override
  void dispose() {
    _tenAlbumController.dispose();
    _ngayChupController.dispose();
    _duongDanDriveController.dispose();
    _ghiChuController.dispose();
    _matKhauController.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    setState(() => _dangLuu = true);

    // TODO: thay đoạn delay này bằng gọi AlbumApi.taoMoi({...}) khi có
    // endpoint/payload chính xác.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _dangLuu = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _chonNgayChup() async {
    final ket = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (ket == null) return;
    setState(() {
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
              decoration: const InputDecoration(labelText: 'Tên album'),
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
