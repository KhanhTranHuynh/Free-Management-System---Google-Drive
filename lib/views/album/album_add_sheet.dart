import 'package:flutter/material.dart';

/// Form Thêm album — convert khung từ AddAlbumModal.jsx (chưa có nội dung
/// gốc để đối chiếu field chính xác, nên chỉ dựng khung + TODO).
/// Trả về `true` qua Navigator.pop khi tạo thành công để AlbumListView biết
/// mà tải lại danh sách — khớp prop `onCreated` bên React.
class AlbumAddSheet extends StatefulWidget {
  const AlbumAddSheet({super.key, required this.khachHangOptions});

  final List<Map<String, dynamic>> khachHangOptions;

  @override
  State<AlbumAddSheet> createState() => _AlbumAddSheetState();
}

class _AlbumAddSheetState extends State<AlbumAddSheet> {
  final _tenAlbumController = TextEditingController();
  Map<String, dynamic>? _khachHangDaChon;
  bool _dangLuu = false;

  @override
  void dispose() {
    _tenAlbumController.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    setState(() => _dangLuu = true);
    // TODO: gọi AlbumApi.them({...}) khi có endpoint/field cụ thể.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _dangLuu = false);
    Navigator.of(context).pop(true);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thêm album', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _tenAlbumController,
            decoration: const InputDecoration(labelText: 'Tên album'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _khachHangDaChon,
            decoration: const InputDecoration(labelText: 'Khách hàng'),
            items: [
              for (final kh in widget.khachHangOptions)
                DropdownMenuItem(
                  value: kh,
                  child: Text(kh['ten_khach_hang']?.toString() ?? '--'),
                ),
            ],
            onChanged: (v) => setState(() => _khachHangDaChon = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _dangLuu ? null : _luu,
            child: _dangLuu
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
