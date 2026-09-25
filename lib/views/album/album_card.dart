import 'package:flutter/material.dart';

import '../../components/app_images.dart';

/// Mô tả 1 action trong menu của card (xem/sửa/hoàn thành/huỷ/phân công/xoá).
class AlbumCardAction {
  const AlbumCardAction({
    required this.nhan,
    required this.icon,
    required this.onTap,
    this.nguyHiem = false,
  });

  final String nhan;
  final IconData icon;
  final VoidCallback onTap;
  final bool nguyHiem;
}

/// Card hiển thị 1 album trong lưới. Convert từ AlbumCard.jsx.
///
/// FIX: thêm ảnh bìa lấy từ field `thumbnail_view` (link dạng
/// lh3.googleusercontent.com) ở đầu card, hiển thị qua widget `AnhMang`
/// dùng chung (lib/components/app_images.dart) — widget này tự lo resize
/// theo kích thước card, loading placeholder và fallback khi thiếu/lỗi
/// ảnh, nên ở đây chỉ cần truyền URL vào.
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.data,
    required this.trangThai,
    required this.onTap,
    required this.actions,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic>? trangThai;
  final VoidCallback onTap;
  final List<AlbumCardAction> actions;

  @override
  Widget build(BuildContext context) {
    final tenAlbum = data['ten_album']?.toString() ?? '--';
    final tenKhachHang = data['ten_khach_hang']?.toString() ?? '--';
    final tenHienThiTrangThai = trangThai?['ten_hien_thi']?.toString() ?? '--';
    final mauSac = _parseMau(trangThai?['mau_sac']?.toString());
    final anhBia = data['thumbnail_view']?.toString();
    final coAnhBia = anhBia != null && anhBia.trim().isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chỉ chiếm chỗ khi có ảnh bìa thật sự — album không có ảnh sẽ
            // không hiện khung fallback (icon vỡ ảnh), tiết kiệm không
            // gian và đỡ nhìn như lỗi.
            if (coAnhBia)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: AnhMang(
                  url: anhBia,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Resize theo bề rộng ước lượng của 1 ô lưới — card đủ nhỏ
                  // để không cần tải bản full-size của Drive.
                  kichThuocResize: 400,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenAlbum,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (actions.isNotEmpty)
                          PopupMenuButton<AlbumCardAction>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (a) => a.onTap(),
                            itemBuilder: (context) => [
                              for (final a in actions)
                                PopupMenuItem(
                                  value: a,
                                  child: Row(
                                    children: [
                                      Icon(
                                        a.icon,
                                        size: 18,
                                        color: a.nguyHiem
                                            ? Theme.of(context)
                                                .colorScheme
                                                .error
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        a.nhan,
                                        style: TextStyle(
                                          color: a.nguyHiem
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .error
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenKhachHang,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: mauSac.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tenHienThiTrangThai,
                          style: TextStyle(color: mauSac, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseMau(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final s = hex.replaceAll('#', '');
    final value = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
    return value == null ? Colors.grey : Color(value);
  }
}
