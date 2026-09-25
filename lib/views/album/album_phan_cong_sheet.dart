import 'package:flutter/material.dart';

/// Form Phân công album — convert khung từ PhanCongAlbumModal.jsx.
/// Trả về `true` khi phân công thành công để AlbumListView tải lại.
class AlbumPhanCongSheet extends StatefulWidget {
  const AlbumPhanCongSheet({
    super.key,
    required this.album,
    required this.nhanVienOptions,
  });

  final Map<String, dynamic> album;
  final List<Map<String, dynamic>> nhanVienOptions;

  @override
  State<AlbumPhanCongSheet> createState() => _AlbumPhanCongSheetState();
}

class _AlbumPhanCongSheetState extends State<AlbumPhanCongSheet> {
  Map<String, dynamic>? _nhanVienDaChon;
  bool _dangLuu = false;

  Future<void> _luu() async {
    if (_nhanVienDaChon == null) return;
    setState(() => _dangLuu = true);
    // TODO: gọi LichPhanCongApi.them({id_album: widget.album['id_album'], ...})
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
          Text('Phân công album',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _nhanVienDaChon,
            decoration: const InputDecoration(labelText: 'Nhân viên'),
            items: [
              for (final nv in widget.nhanVienOptions)
                DropdownMenuItem(
                  value: nv,
                  child: Text(nv['ho_ten']?.toString() ?? '--'),
                ),
            ],
            onChanged: (v) => setState(() => _nhanVienDaChon = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_dangLuu || _nhanVienDaChon == null) ? null : _luu,
            child: _dangLuu
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Phân công'),
          ),
        ],
      ),
    );
  }
}
