import 'package:flutter/material.dart';

import '../../../../configs/app_colors.dart';

/// Tương ứng PhotoGrid.jsx. Trả về Sliver để nhúng vào CustomScrollView
/// của view cha (infinite scroll do controller cha lo qua ScrollController).
class PhotoGridSliver extends StatelessWidget {
  const PhotoGridSliver({
    super.key,
    required this.anhList,
    required this.isLoading,
    required this.isLoadingMore,
    required this.emptyMessage,
    required this.onSelectPhoto,
    this.error,
    this.idAnhDangXem,
    this.onOpenGallery,
    this.onToggleChonAnh,
    this.dangDoiChonIds = const {},
    this.onXoaYeuCauAnh,
    this.dangXoaYeuCauIds = const {},
    this.anBadgeTrangThai = false,
  });

  final List<Map<String, dynamic>> anhList;
  final bool isLoading;
  final bool isLoadingMore;
  final String emptyMessage;
  final String? error;
  final String? idAnhDangXem;
  final ValueChanged<Map<String, dynamic>> onSelectPhoto;
  final ValueChanged<Map<String, dynamic>>? onOpenGallery;

  /// null = không có quyền chọn.
  final ValueChanged<Map<String, dynamic>>? onToggleChonAnh;
  final Set<String> dangDoiChonIds;

  /// null = không có quyền huỷ yêu cầu.
  final ValueChanged<Map<String, dynamic>>? onXoaYeuCauAnh;
  final Set<String> dangXoaYeuCauIds;
  final bool anBadgeTrangThai;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (anhList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error ?? emptyMessage, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final a = anhList[i];
                final id = a['id_tep_anh'].toString();
                return PhotoTile(
                  key: ValueKey(id),
                  anh: a,
                  dangXemChiTiet: idAnhDangXem == id,
                  dangDoiChon: dangDoiChonIds.contains(id),
                  dangXoaYeuCau: dangXoaYeuCauIds.contains(id),
                  anBadgeTrangThai: anBadgeTrangThai,
                  onTap: () => onSelectPhoto(a),
                  onLongPress:
                      onOpenGallery == null ? null : () => onOpenGallery!(a),
                  onToggleChon: onToggleChonAnh == null
                      ? null
                      : () => onToggleChonAnh!(a),
                  onXoaYeuCau:
                      onXoaYeuCauAnh == null ? null : () => onXoaYeuCauAnh!(a),
                );
              },
              childCount: anhList.length,
            ),
          ),
        ),
        if (isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        if (error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Không tải được thêm ảnh. Vui lòng thử lại sau.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
      ],
    );
  }
}

/// Nhãn badge: "Ảnh gốc" / "Ver n" + trạng thái (tương ứng layNhanBadge).
({String phienBan, String? trangThai}) layNhanBadge(Map<String, dynamic> a) {
  final lan = (a['lan_sua_hien_tai'] as num?)?.toInt() ?? 0;
  final phienBan = lan == 0 ? 'Ảnh gốc' : 'Ver $lan';

  final tt = a['trang_thai_anh']?.toString();
  String? text;
  if (tt == 'da_yeu_cau') {
    text =
        a['lan_chinh_sua_moi_nhat'] != null && a['lan_chinh_sua_moi_nhat'] != 0
            ? 'Đã thêm yêu cầu'
            : 'Đã yêu cầu';
  } else if (tt == 'da_chot') {
    final dot = (a['lan_chot_thu_moi_nhat'] as num?)?.toInt() ?? 0;
    text = dot > 0 ? 'Đã chốt đợt $dot' : 'Đã chốt';
  }
  return (phienBan: phienBan, trangThai: text);
}

String _duoiFile(String? ten) {
  if (ten == null) return '';
  final i = ten.lastIndexOf('.');
  if (i == -1 || i == ten.length - 1) return '';
  return ten.substring(i + 1).toUpperCase();
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.anh,
    required this.onTap,
    this.onLongPress,
    this.onToggleChon,
    this.onXoaYeuCau,
    this.dangXemChiTiet = false,
    this.dangDoiChon = false,
    this.dangXoaYeuCau = false,
    this.anBadgeTrangThai = false,
  });

  final Map<String, dynamic> anh;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleChon;
  final VoidCallback? onXoaYeuCau;
  final bool dangXemChiTiet;
  final bool dangDoiChon;
  final bool dangXoaYeuCau;
  final bool anBadgeTrangThai;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badge = layNhanBadge(anh);
    final trangThaiText = anBadgeTrangThai ? null : badge.trangThai;
    final duocChon = anh['duoc_khach_chon'] == true;
    final duocPhepChon = anh['duoc_phep_chon'] == true;
    final duocPhepHuy = anh['duoc_phep_huy_yeu_cau'] == true;
    final url = anh['duong_dan_preview']?.toString() ??
        anh['duong_dan_drive_xem']?.toString();
    final duoi = _duoiFile(anh['ten_tep_goc']?.toString());

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dangXemChiTiet ? AppColors.primary : cs.outlineVariant,
            width: dangXemChiTiet ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: cs.surfaceContainerHighest,
                    child: url != null
                        ? Image.network(url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey))
                        : const Icon(Icons.image, size: 32, color: Colors.grey),
                  ),
                  Positioned(
                      left: 6, top: 6, child: _Badge(text: badge.phienBan)),
                  if (trangThaiText != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child:
                          _Badge(text: trangThaiText, color: AppColors.primary),
                    ),
                  if (duocPhepHuy)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _RoundButton(
                        color: onXoaYeuCau != null
                            ? Colors.red.shade600
                            : Colors.red.shade300,
                        loading: dangXoaYeuCau,
                        icon: Icons.close,
                        onTap: (onXoaYeuCau == null || dangXoaYeuCau)
                            ? null
                            : onXoaYeuCau,
                      ),
                    )
                  else if (duocPhepChon)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _RoundButton(
                        color: duocChon ? AppColors.primary : Colors.black54,
                        loading: dangDoiChon,
                        icon: Icons.check,
                        onTap: (onToggleChon == null || dangDoiChon)
                            ? null
                            : onToggleChon,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(anh['ten_tep_goc']?.toString() ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(duoi.isEmpty ? '—' : duoi,
                            style: TextStyle(fontSize: 9, color: cs.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color ?? Colors.black54,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.loading,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: loading
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 14, color: Colors.white),
        ),
      );
}
