import 'package:flutter/material.dart';

import '../../../components/app_modal.dart';
import '../../../components/o_tim_kiem.dart';
import '../../../configs/app_colors.dart';
import 'album_detail_constants.dart';

const String _tatCa = 'tat_ca';

/// Mô tả 1 ô lọc. View cha quyết định hiện ô nào theo tab,
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

  bool get dangLoc => value != _tatCa;

  String get nhanDangChon {
    for (final o in options) {
      if (o['value'] == value) return o['label'] ?? '--';
    }
    return value;
  }
}

/// Tương ứng PhotoFilterBar.jsx: tiêu đề, tìm kiếm (OTimKiem), nút lọc mở
/// popup (showAppModal), pill bộ lọc đang bật, nút hành động.
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

  // ---------------------------------------------------------------------
  // Popup lọc
  // ---------------------------------------------------------------------
  Future<void> _moPopupLoc(BuildContext context) async {
    FocusScope.of(context).unfocus();

    // State tạm của từng bộ lọc (theo thứ tự trong `filters`).
    final tam = ValueNotifier<List<String>>([for (final f in filters) f.value]);

    final apDung = await showAppModal<bool>(
      context,
      title: 'Lọc ảnh',
      subTitle: 'Chọn điều kiện lọc danh sách ảnh',
      type: AppModalType.bottomSheet,
      closeOnBackdropClick: true,
      builder: (_) => _LocForm(filters: filters, tam: tam),
      footerBuilder: (ctx) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                tam.value = List<String>.filled(filters.length, _tatCa);
                Navigator.of(ctx).pop(true);
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Xóa lọc'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Áp dụng',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    if (apDung != true) return;

    // Chỉ gọi onChanged cho bộ lọc nào thực sự đổi.
    for (var i = 0; i < filters.length; i++) {
      if (tam.value[i] != filters[i].value) {
        filters[i].onChanged(tam.value[i]);
      }
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          style: _nutStyle(filled: true),
          icon: const Icon(Icons.auto_fix_high, size: 16),
          label: Text(dangChotTatCaAlbum ? 'Đang chốt...' : 'Chốt yêu cầu'),
        ),
      if (onXoaCungTatCaAlbum != null)
        OutlinedButton.icon(
          onPressed: dangXoaCungTatCaAlbum ? null : onXoaCungTatCaAlbum,
          style: _nutStyle(),
          icon: const Icon(Icons.delete_forever, size: 16),
          label: Text(
              dangXoaCungTatCaAlbum ? 'Đang xóa...' : 'Hủy yêu cầu chưa chốt'),
        ),
      if (onTaiAnhVe != null)
        PopupMenuButton<String>(
          enabled: !dangTaiAnhVe,
          onSelected: onTaiAnhVe,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'tat_ca', child: Text(nhanTatCa)),
            PopupMenuItem(value: 'bo_loc', child: Text(nhanBoLoc)),
          ],
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: dangTaiAnhVe ? null : () {},
              style: _nutStyle(),
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
          style: _nutStyle(),
          icon: const Icon(Icons.compare_arrows, size: 16),
          label: const Text('Đối chiếu ảnh'),
        ),
      if (onUploadToanBo != null)
        OutlinedButton.icon(
          onPressed: onUploadToanBo,
          style: _nutStyle(),
          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
          label: const Text('Upload toàn bộ ảnh đã sửa'),
        ),
    ];

    final dangBat = filters.where((f) => f.dangLoc).toList();
    final dangLoc = dangBat.isNotEmpty;
    final tieuDe = AlbumTab.titles[activeTab] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tongSo == null ? tieuDe : '$tieuDe ($tongSo)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          // ----- Tìm kiếm + nút lọc -----
          Row(
            children: [
              Expanded(
                child: OTimKiem(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  hintText: 'Tìm tên file ảnh...',
                ),
              ),
              if (filters.isNotEmpty) ...[
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: dangLoc,
                  label: Text('${dangBat.length}'),
                  backgroundColor: AppColors.primary,
                  child: Container(
                    decoration: BoxDecoration(
                      color: dangLoc
                          ? AppColors.primary.withOpacity(0.12)
                          : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      tooltip: dangLoc
                          ? 'Đang áp dụng ${dangBat.length} bộ lọc — bấm để đổi'
                          : 'Bộ lọc',
                      onPressed: () => _moPopupLoc(context),
                      icon: Icon(
                        Icons.filter_list_rounded,
                        color: dangLoc ? AppColors.primary : null,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ----- Pill các bộ lọc đang bật -----
          if (dangLoc) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in dangBat)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        text: '${f.label}: ${f.nhanDangChon}',
                        onTap: () => _moPopupLoc(context),
                        onClear: () => f.onChanged(_tatCa),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ----- Nút hành động -----
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
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

  ButtonStyle _nutStyle({bool filled = false}) => ButtonStyle(
        shape: WidgetStatePropertyAll(const StadiumBorder()),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        backgroundColor:
            filled ? const WidgetStatePropertyAll(AppColors.primary) : null,
      );
}

// ============================================================
// Pill tóm tắt 1 bộ lọc đang bật — bấm để mở popup, bấm X để bỏ.
// ============================================================
class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.onTap,
    required this.onClear,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 7, 10, 7),
              child: Icon(Icons.close_rounded,
                  size: 16, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Thân popup: mỗi bộ lọc = nhãn + hàng ChoiceChip.
// ============================================================
class _LocForm extends StatelessWidget {
  const _LocForm({required this.filters, required this.tam});

  final List<FilterSpec> filters;
  final ValueNotifier<List<String>> tam;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: tam,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < filters.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              Text(
                filters[i].label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(i, 'Tất cả', _tatCa),
                  for (final o in filters[i].options)
                    if (o['value'] != _tatCa)
                      _chip(i, o['label'] ?? '--', o['value'] ?? ''),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _chip(int index, String nhan, String gia) {
    final chon = tam.value[index] == gia;
    return ChoiceChip(
      label: Text(nhan),
      selected: chon,
      showCheckmark: false,
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: chon ? AppColors.primary : null,
      ),
      shape: const StadiumBorder(),
      onSelected: (_) {
        final moi = [...tam.value];
        moi[index] = gia;
        tam.value = moi;
      },
    );
  }
}
