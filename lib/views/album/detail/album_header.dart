import 'package:flutter/material.dart';

import '../../../../configs/app_colors.dart';
import 'album_detail_constants.dart';

/// Tương ứng AlbumHeader.jsx: thông tin album + thẻ tab có số đếm.
class AlbumHeader extends StatelessWidget {
  const AlbumHeader({
    super.key,
    required this.album,
    required this.isLoading,
    required this.thongKe,
    required this.activeTab,
    required this.onChangeTab,
    this.albumDaKhoa = false,
    this.onSuaAlbum,
    this.onTaiAnhLenDrive,
  });

  final Map<String, dynamic>? album;
  final bool isLoading;
  final Map<String, dynamic> thongKe;
  final String activeTab;
  final ValueChanged<String> onChangeTab;
  final bool albumDaKhoa;

  /// null = ẩn nút. TODO: nối EditAlbum / UploadDrive khi có view tương ứng.
  final VoidCallback? onSuaAlbum;
  final VoidCallback? onTaiAnhLenDrive;

  int _n(String k) => (thongKe[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    if (album == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final a = album!;
    final cs = Theme.of(context).colorScheme;
    final soLan = a['so_lan_chinh_sua_mien_phi'];
    final daChot = a['lan_chot_yeu_cau_chinh_sua'] ?? 0;
    final soLanLabel =
        soLan == null ? '$daChot (Không giới hạn)' : '$daChot/$soLan';

    final counts = {
      AlbumTab.anh: _n('tong_so_hinh'),
      AlbumTab.yeuCau: _n('tong_so_yeu_cau_chua_chot'),
      AlbumTab.chotYeuCau: _n('tong_so_yeu_cau_da_chot'),
      AlbumTab.daSua: _n('tong_hinh_da_sua'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a['ten_album']?.toString() ?? '—',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _StatusBadge(
                      text: (a['trang_thai_hien_thi'] ?? a['trang_thai'] ?? '—')
                          .toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _FlagChip(
                        on: a['cho_phep_xem_khong_dang_nhap'] == true,
                        label: 'Công khai'),
                    _FlagChip(
                        on: a['cho_phep_tai'] == true, label: 'Cho phép tải'),
                  ],
                ),
                const Divider(height: 20),
                _MetaRow(
                    icon: Icons.person_outline,
                    label: 'Khách hàng',
                    value:
                        a['khach_hang']?['ho_ten']?.toString() ?? 'Không có'),
                _MetaRow(
                    icon: Icons.edit_outlined,
                    label: 'Số lần chỉnh sửa miễn phí',
                    value: soLanLabel),
                _MetaRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Ngày tạo',
                    value: a['created_at']?.toString().split('T').first ?? '—'),
                _MetaRow(
                    icon: Icons.qr_code_2,
                    label: 'Mã truy cập công khai',
                    value: a['ma_truy_cap_cong_khai']?.toString() ?? 'Chưa có'),
                if ((a['ghi_chu']?.toString() ?? '').isNotEmpty)
                  _MetaRow(
                      icon: Icons.notes,
                      label: 'Ghi chú',
                      value: a['ghi_chu'].toString()),
                if (!albumDaKhoa &&
                    (onSuaAlbum != null || onTaiAnhLenDrive != null)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (onSuaAlbum != null)
                        OutlinedButton.icon(
                          onPressed: onSuaAlbum,
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Chỉnh sửa'),
                        ),
                      if (onTaiAnhLenDrive != null)
                        FilledButton.icon(
                          onPressed: onTaiAnhLenDrive,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          icon: const Icon(Icons.drive_folder_upload, size: 14),
                          label: const Text('Tải ảnh lên qua Drive'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: AlbumTab.all.map((tab) {
              final active = tab == activeTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: active,
                  selectedColor: AppColors.primary,
                  backgroundColor: cs.surfaceContainerHigh,
                  showCheckmark: false,
                  onSelected: (_) => onChangeTab(tab),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AlbumTab.labels[tab]!,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : null),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${counts[tab]}',
                        style: TextStyle(
                            fontSize: 10,
                            color: active ? Colors.white70 : cs.outline),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: cs.outline)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      );
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.on, required this.label});
  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.check_circle : Icons.cancel, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
