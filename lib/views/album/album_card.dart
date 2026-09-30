import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/time_util.dart';
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

/// Card album: ảnh bìa (pill trạng thái + nút ⋮ đè lên ảnh), tiêu đề,
/// các dòng thông tin phụ và hàng "Mã truy cập" + nút copy.
///
/// Chiều cao card do lưới quyết định (mainAxisExtent). Phần thông tin có
/// chiều cao đúng bằng nội dung, ảnh bìa lấp đầy phần còn lại.
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

  static const Color _maBg = Color(0xFFF8F9FB);
  static const Color _maText = Color(0xFF9A6B2F);

  /// Lấy giá trị đầu tiên khác rỗng trong danh sách key dự phòng.
  String? _layGiaTri(List<String> keys) {
    for (final k in keys) {
      final v = data[k]?.toString();
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tenAlbum = data['ten_album']?.toString() ?? '--';
    final soLanSua = data['so_lan_chinh_sua_mien_phi']?.toString() ?? '0';
    final tongAnh = data['tong_so_anh']?.toString() ?? '0';
    final ngayTao = formatDate(
      _layGiaTri(['create_at', 'created_at', 'ngay_tao', 'ngay_tao_album']),
    );
    final maTruyCap =
        _layGiaTri(['ma_truy_cap_cong_khai', 'ma_truy_cap', 'ma_cong_khai']) ??
            '';
    final tenTrangThai = trangThai?['ten_hien_thi']?.toString() ?? '--';
    final mauSac = _parseMau(trangThai?['mau_sac']?.toString());
    final anhBia = data['thumbnail_view']?.toString();
    final coAnhBia = anhBia != null && anhBia.trim().isNotEmpty;

    final subStyle = TextStyle(
      fontSize: 15,
      height: 1.3,
      color: cs.onSurfaceVariant.withOpacity(0.8),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- Ảnh bìa: chiếm toàn bộ chỗ còn lại ----------
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coAnhBia)
                    AnhMang(
                      url: anhBia,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      kichThuocResize: 800,
                    )
                  else
                    Container(
                      color: cs.surfaceContainerHigh,
                      alignment: Alignment.center,
                      child: Icon(Icons.photo_library_outlined,
                          size: 40, color: cs.onSurfaceVariant),
                    ),
                  // Pill trạng thái (góc trái)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: mauSac,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tenTrangThai,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Nút ⋮ (góc phải)
                  if (actions.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _buildMenu(context),
                    ),
                ],
              ),
            ),

            // ---------- Thông tin: cao đúng bằng nội dung ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenAlbum,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Số lần chỉnh sửa miễn phí: $soLanSua',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subStyle),
                  Text('Tổng số ảnh: $tongAnh', style: subStyle),
                  Text('Ngày tạo: $ngayTao', style: subStyle),
                  const SizedBox(height: 10),
                  _buildMaTruyCap(context, maTruyCap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<AlbumCardAction>(
      tooltip: 'Tác vụ',
      onSelected: (a) => a.onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_vert, size: 20, color: cs.onSurfaceVariant),
      ),
      itemBuilder: (context) => [
        for (final a in actions)
          PopupMenuItem(
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 18, color: a.nguyHiem ? cs.error : null),
                const SizedBox(width: 8),
                Text(a.nhan,
                    style: TextStyle(color: a.nguyHiem ? cs.error : null)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMaTruyCap(BuildContext context, String ma) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _maBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 18, color: _maText),
                const SizedBox(width: 6),
                // FittedBox: mã dài quá thì tự thu nhỏ chữ, không bị cắt "..."
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mã truy cập: ${ma.isEmpty ? '--' : ma}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: _maText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: _maBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: ma.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: ma));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                            content: Text('Đã sao chép mã truy cập')),
                      );
                  },
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.copy_rounded, size: 18, color: _maText),
            ),
          ),
        ),
      ],
    );
  }

  Color _parseMau(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final s = hex.replaceAll('#', '');
    final value = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
    return value == null ? Colors.grey : Color(value);
  }
}
