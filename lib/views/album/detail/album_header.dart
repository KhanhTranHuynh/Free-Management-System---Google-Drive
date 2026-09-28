import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.trangThaiHienTai,
    this.albumDaKhoa = false,
    this.hienMatKhau = false,
    this.layMatKhau,
    this.onSuaAlbum,
    this.onTaiAnhLenDrive,
  });

  final Map<String, dynamic>? album;
  final bool isLoading;
  final Map<String, dynamic> thongKe;
  final String activeTab;
  final ValueChanged<String> onChangeTab;

  /// Item trong danh sách trạng thái (ten_hien_thi, mau_sac...).
  final Map<String, dynamic>? trangThaiHienTai;
  final bool albumDaKhoa;

  /// laNhanVien && coQuyenXemMatKhau.
  final bool hienMatKhau;
  final Future<String?> Function()? layMatKhau;

  /// null = ẩn nút.
  final VoidCallback? onSuaAlbum;
  final VoidCallback? onTaiAnhLenDrive;

  int _n(String k) => (thongKe[k] as num?)?.toInt() ?? 0;

  static Color _mau(String? hex) {
    try {
      final h = (hex ?? '#748091').replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF748091);
    }
  }

  static String _ngay(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  static String _dungLuong(dynamic v) {
    final b =
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    if (b <= 0) return '0 B';
    const u = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var x = b;
    while (x >= 1024 && i < u.length - 1) {
      x /= 1024;
      i++;
    }
    return '${x.toStringAsFixed(i == 0 ? 0 : 1)} ${u[i]}';
  }

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

    final tenTrangThai = (trangThaiHienTai?['ten_hien_thi'] ??
            a['trang_thai_hien_thi'] ??
            a['trang_thai'] ??
            '—')
        .toString();
    final mauTrangThai = _mau(trangThaiHienTai?['mau_sac']?.toString());

    final ma = a['ma_truy_cap_cong_khai']?.toString();
    final linkChiaSe = (ma == null || ma.isEmpty)
        ? null
        : '${AlbumConfig.clientUrl}/chi-tiet-album/$ma';
    final thumb = a['thumbnail_url']?.toString();

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 96,
                        height: 68,
                        child: thumb != null && thumb.isNotEmpty
                            ? Image.network(thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: cs.surfaceContainerHighest))
                            : Container(color: cs.surfaceContainerHighest),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['ten_album']?.toString() ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          _Pill(text: tenTrangThai, color: mauTrangThai),
                        ],
                      ),
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
                    value: _ngay(a['created_at'])),
                _MetaRow(
                    icon: Icons.archive_outlined,
                    label: 'Dung lượng sử dụng',
                    value: _dungLuong(a['dung_luong_su_dung'])),
                _MetaRow(
                    icon: Icons.notes,
                    label: 'Ghi chú',
                    value: (a['ghi_chu']?.toString() ?? '').isEmpty
                        ? '—'
                        : a['ghi_chu'].toString()),
                _MaTruyCapRow(
                    ma: ma, link: linkChiaSe, tenAlbum: a['ten_album']),
                if (hienMatKhau && layMatKhau != null)
                  _MatKhauRow(
                    key: ValueKey('${a['id_album']}-${a['updated_at']}'),
                    layMatKhau: layMatKhau!,
                  ),
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

void _copy(BuildContext context, String text, String msg) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Ô "Mã truy cập công khai": bấm -> QR + copy link.
class _MaTruyCapRow extends StatelessWidget {
  const _MaTruyCapRow({required this.ma, required this.link, this.tenAlbum});
  final String? ma;
  final String? link;
  final dynamic tenAlbum;

  void _moQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Mã truy cập công khai', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(link!)}',
              width: 180,
              height: 180,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.qr_code_2, size: 96),
            ),
            const SizedBox(height: 10),
            SelectableText(link!, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 6),
            Text('Mã: $ma',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => _copy(ctx, link!, 'Đã sao chép link'),
              child: const Text('Sao chép')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: link == null ? null : () => _moQr(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã truy cập công khai',
                      style: TextStyle(fontSize: 10, color: cs.outline)),
                  Text(
                    (ma == null || ma!.isEmpty) ? 'Chưa có' : ma!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: link == null ? null : AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
          if (link != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              tooltip: 'Sao chép link',
              onPressed: () => _copy(context, link!, 'Đã sao chép link'),
              icon: const Icon(Icons.copy),
            ),
        ],
      ),
    );
  }
}

/// Ô "Mật khẩu truy cập": che mờ, bấm mới gọi API (MatKhauMetaItem).
class _MatKhauRow extends StatefulWidget {
  const _MatKhauRow({super.key, required this.layMatKhau});
  final Future<String?> Function() layMatKhau;

  @override
  State<_MatKhauRow> createState() => _MatKhauRowState();
}

class _MatKhauRowState extends State<_MatKhauRow> {
  bool _hien = false;
  bool _daTai = false;
  bool _dang = false;
  String? _matKhau;

  Future<void> _bam() async {
    if (_dang) return;
    if (_hien) {
      setState(() => _hien = false);
      return;
    }
    if (_daTai) {
      setState(() => _hien = true);
      return;
    }
    setState(() => _dang = true);
    try {
      final mk = await widget.layMatKhau();
      if (!mounted) return;
      setState(() {
        _matKhau = mk;
        _daTai = true;
        _hien = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lấy mật khẩu thất bại')));
      }
    }
    if (mounted) setState(() => _dang = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final giaTri = _dang
        ? 'Đang tải...'
        : _hien
            ? ((_matKhau == null || _matKhau!.isEmpty)
                ? 'Album chưa đặt mật khẩu'
                : _matKhau!)
            : '••••••••';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_hien ? Icons.visibility_off : Icons.visibility,
              size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: _bam,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mật khẩu truy cập',
                      style: TextStyle(fontSize: 10, color: cs.outline)),
                  Text(giaTri,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
          if (_hien && (_matKhau ?? '').isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              tooltip: 'Sao chép mật khẩu',
              onPressed: () =>
                  _copy(context, _matKhau!, 'Đã sao chép mật khẩu'),
              icon: const Icon(Icons.copy),
            ),
        ],
      ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
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
