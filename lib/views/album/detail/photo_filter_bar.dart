import 'package:flutter/material.dart';

import 'album_detail_constants.dart';

/// Mô tả 1 ô lọc (dropdown). View cha quyết định hiện ô nào theo tab,
/// giống các cờ showXxxFilter của PhotoFilterBar.jsx.
class FilterSpec {
  const FilterSpec({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;

  /// [{value,label}] — KHÔNG cần thêm "Tất cả", widget tự thêm.
  final List<Map<String, String>> options;
  final ValueChanged<String> onChanged;
}

/// Tương ứng PhotoFilterBar.jsx: tiêu đề, tìm kiếm, filter, nút hành động.
class PhotoFilterBar extends StatelessWidget {
  const PhotoFilterBar({
    super.key,
    required this.activeTab,
    required this.searchController,
    required this.onSearchChanged,
    this.tongSo,
    this.filters = const [],
    this.onChotTatCaAlbum,
    this.dangChotTatCaAlbum = false,
    this.onXoaCungTatCaAlbum,
    this.dangXoaCungTatCaAlbum = false,
    this.onTaiAnhVe,
    this.dangTaiAnhVe = false,
    this.soLuongTaiTatCa,
    this.soLuongTaiBoLoc,
    this.onDoiChieuAnh,
    this.onUploadToanBo,
  });

  final String activeTab;
  final int? tongSo;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<FilterSpec> filters;

  // null = ẩn nút (giống cách React truyền undefined)
  final VoidCallback? onChotTatCaAlbum;
  final bool dangChotTatCaAlbum;
  final VoidCallback? onXoaCungTatCaAlbum;
  final bool dangXoaCungTatCaAlbum;

  /// Nhận 'tat_ca' | 'bo_loc'.
  final ValueChanged<String>? onTaiAnhVe;
  final bool dangTaiAnhVe;
  final int? soLuongTaiTatCa;
  final int? soLuongTaiBoLoc;
  final VoidCallback? onDoiChieuAnh;
  final VoidCallback? onUploadToanBo;

  @override
  Widget build(BuildContext context) {
    final nhanTatCa = soLuongTaiTatCa != null
        ? 'Tải tất cả ảnh trong album ($soLuongTaiTatCa)'
        : 'Tải tất cả ảnh trong album';
    final nhanBoLoc = soLuongTaiBoLoc != null
        ? 'Tải ảnh theo bộ lọc hiện tại ($soLuongTaiBoLoc)'
        : 'Tải ảnh theo bộ lọc hiện tại';

    final actions = <Widget>[
      if (onChotTatCaAlbum != null)
        FilledButton.icon(
          onPressed: dangChotTatCaAlbum ? null : onChotTatCaAlbum,
          icon: const Icon(Icons.auto_fix_high, size: 16),
          label: Text(dangChotTatCaAlbum ? 'Đang chốt...' : 'Chốt yêu cầu'),
        ),
      if (onXoaCungTatCaAlbum != null)
        OutlinedButton.icon(
          onPressed: dangXoaCungTatCaAlbum ? null : onXoaCungTatCaAlbum,
          icon: const Icon(Icons.delete_forever, size: 16),
          label: Text(
              dangXoaCungTatCaAlbum ? 'Đang xóa...' : 'Hủy yêu cầu chưa chốt'),
        ),
      if (onTaiAnhVe != null)
        PopupMenuButton<String>(
          enabled: !dangTaiAnhVe,
          onSelected: onTaiAnhVe,
          itemBuilder: (_) => [
            PopupMenuItem(value: 'tat_ca', child: Text(nhanTatCa)),
            PopupMenuItem(value: 'bo_loc', child: Text(nhanBoLoc)),
          ],
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: dangTaiAnhVe ? null : () {},
              icon: dangTaiAnhVe
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download, size: 16),
              label: const Text('Tải ảnh drive'),
            ),
          ),
        ),
      if (onDoiChieuAnh != null)
        OutlinedButton.icon(
          onPressed: onDoiChieuAnh,
          icon: const Icon(Icons.compare_arrows, size: 16),
          label: const Text('Đối chiếu ảnh'),
        ),
      if (onUploadToanBo != null)
        OutlinedButton.icon(
          onPressed: onUploadToanBo,
          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
          label: const Text('Upload toàn bộ ảnh đã sửa'),
        ),
    ];

    final soDangLoc = filters.where((f) => f.value != 'tat_ca').length;
    final tieuDe = AlbumTab.titles[activeTab] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tongSo == null ? tieuDe : '$tieuDe ($tongSo)',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Tìm tên file ảnh...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in filters)
                    SizedBox(width: w, child: _FilterDropdown(spec: f)),
                ],
              );
            }),
            if (soDangLoc > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Đang áp dụng $soDangLoc bộ lọc',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary)),
              ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: actions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => actions[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.spec});
  final FilterSpec spec;

  @override
  Widget build(BuildContext context) {
    final dangLoc = spec.value != 'tat_ca';
    final primary = Theme.of(context).colorScheme.primary;
    final options = [
      {'value': 'tat_ca', 'label': 'Tất cả'},
      ...spec.options.where((o) => o['value'] != 'tat_ca'),
    ];
    final safe =
        options.any((o) => o['value'] == spec.value) ? spec.value : 'tat_ca';
    return DropdownButtonFormField<String>(
      value: safe,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: spec.label,
        isDense: true,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: dangLoc ? primary : Colors.grey, width: dangLoc ? 2 : 1),
        ),
        filled: dangLoc,
        fillColor: dangLoc ? primary.withOpacity(0.08) : null,
      ),
      items: options
          .map((o) => DropdownMenuItem(
                value: o['value'],
                child: Text(o['label'] ?? '', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => spec.onChanged(v ?? 'tat_ca'),
    );
  }
}
