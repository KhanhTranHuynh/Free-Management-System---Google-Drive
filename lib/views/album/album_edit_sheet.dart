import 'package:flutter/material.dart';

/// Form Sửa album — convert khung từ EditAlbumModal.jsx.
/// Trả về `true` khi lưu thành công để AlbumListView tải lại — khớp prop
/// `onUpdated` bên React.
class AlbumEditSheet extends StatefulWidget {
  const AlbumEditSheet({
    super.key,
    required this.album,
    required this.khachHangOptions,
  });

  final Map<String, dynamic> album;
  final List<Map<String, dynamic>> khachHangOptions;

  @override
  State<AlbumEditSheet> createState() => _AlbumEditSheetState();
}

class _AlbumEditSheetState extends State<AlbumEditSheet> {
  late final _tenAlbumController =
      TextEditingController(text: widget.album['ten_album']?.toString());
  bool _dangLuu = false;

  @override
  void dispose() {
    _tenAlbumController.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    setState(() => _dangLuu = true);
    // TODO: gọi AlbumApi.capNhat(idAlbum: widget.album['id_album'], {...})
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
          Text('Sửa album', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _tenAlbumController,
            decoration: const InputDecoration(labelText: 'Tên album'),
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
