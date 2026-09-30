import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/app_images.dart';
import '../../../configs/app_colors.dart';
import 'album_detail_constants.dart';

/// Tương ứng AlbumHeader.jsx: thông tin album + thẻ tab có số đếm.
/// Màu lấy theo colorScheme nên dùng được cả light và dark.
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

  static const double _chieuCaoAnhBia = 190;

  int _n(String k) => (thongKe[k] as num?)?.toInt() ?? 0;

  static Color _mau(String? hex) {
    try {
      final h = (hex ?? '#748091').replaceAll('#', '');
      return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
    } catch (_) {
      return const Color(0xFF748091);
    }
  }

  /// Lấy giá trị đầu tiên khác rỗng trong danh sách key dự phòng.
  static String? _layGiaTri(Map<String, dynamic> a, List<String> keys) {
    for (final k in keys) {
      final v = a[k]?.toString();
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  static String _ngay(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
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

    final ma = _layGiaTri(a, ['ma_truy_cap_cong_khai', 'ma_truy_cap']);
    final linkChiaSe = (ma == null || ma.isEmpty)
        ? null
        : '${AlbumConfig.clientUrl}/chi-tiet-album/$ma';

    // FIX thumbnail: API trả `thumbnail_view` (giống card ở danh sách),
    // `thumbnail_url` chỉ là dự phòng.
    final anhBia = _layGiaTri(a, ['thumbnail_view', 'thumbnail_url']);

    final ngayTao = _ngay(_layGiaTri(a, ['create_at', 'created_at']));
    final ghiChu = (a['ghi_chu']?.toString() ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Ảnh bìa + pill trạng thái ----------
              SizedBox(
                height: _chieuCaoAnhBia,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (anhBia != null)
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
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: mauTrangThai,
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
                  ],
                ),
              ),

              // ---------- Thông tin ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['ten_album']?.toString() ?? '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _FlagChip(
                            on: a['cho_phep_xem_khong_dang_nhap'] == true,
                            label: 'Công khai'),
                        _FlagChip(
                            on: a['cho_phep_tai'] == true,
                            label: 'Cho phép tải'),
                      ],
                    ),
                    Divider(height: 24, color: cs.outlineVariant),
                    _MetaRow(
                      icon: Icons.person_outline,
                      label: 'Khách hàng',
                      value:
                          a['khach_hang']?['ho_ten']?.toString() ?? 'Không có',
                    ),
                    _MetaRow(
                      icon: Icons.edit_outlined,
                      label: 'Số lần chỉnh sửa miễn phí',
                      value: soLanLabel,
                    ),
                    _MetaRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Ngày tạo',
                      value: ngayTao,
                    ),
                    _MetaRow(
                      icon: Icons.archive_outlined,
                      label: 'Dung lượng sử dụng',
                      value: _dungLuong(a['dung_luong_su_dung']),
                    ),
                    _MetaRow(
                      icon: Icons.notes,
                      label: 'Ghi chú',
                      value: ghiChu.isEmpty ? '—' : ghiChu,
                    ),
                    _MaTruyCapRow(
                        ma: ma, link: linkChiaSe, tenAlbum: a['ten_album']),
                    if (hienMatKhau && layMatKhau != null)
                      _MatKhauRow(
                        key: ValueKey('${a['id_album']}-${a['updated_at']}'),
                        layMatKhau: layMatKhau!,
                      ),
                    if (!albumDaKhoa &&
                        (onSuaAlbum != null || onTaiAnhLenDrive != null)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (onSuaAlbum != null)
                            OutlinedButton.icon(
                              onPressed: onSuaAlbum,
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Chỉnh sửa'),
                            ),
                          if (onTaiAnhLenDrive != null)
                            FilledButton.icon(
                              onPressed: onTaiAnhLenDrive,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              icon: const Icon(Icons.drive_folder_upload,
                                  size: 16),
                              label: const Text('Tải ảnh lên qua Drive'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ---------- Tabs có số đếm ----------
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: AlbumTab.all.map((tab) {
              final active = tab == activeTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: active,
                  selectedColor: AppColors.primary,
                  backgroundColor: cs.surfaceContainerHigh,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  showCheckmark: false,
                  onSelected: (_) => onChangeTab(tab),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AlbumTab.labels[tab]!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${counts[tab]}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white70 : cs.onSurfaceVariant,
                        ),
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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Mã truy cập công khai',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nền trắng cố định để mã QR luôn quét được ở dark mode.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(link!)}',
                  width: 180,
                  height: 180,
                  errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2,
                      size: 96, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(link!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text('Mã: $ma',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => _copy(ctx, link!, 'Đã sao chép link'),
                child: const Text('Sao chép')),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: link == null ? null : () => _moQr(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã truy cập công khai',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  Text(
                    (ma == null || ma!.isEmpty) ? 'Chưa có' : ma!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: link == null ? cs.onSurface : cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (link != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(_hien ? Icons.visibility_off : Icons.visibility,
              size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: _bam,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mật khẩu truy cập',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  Text(giaTri,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
          if (_hien && (_matKhau ?? '').isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.on, required this.label});
  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Xanh đậm cho light, xanh sáng cho dark; tắt thì dùng màu trung tính.
    final color = on
        ? (dark ? Colors.green.shade300 : Colors.green.shade700)
        : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.check_circle : Icons.cancel, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
