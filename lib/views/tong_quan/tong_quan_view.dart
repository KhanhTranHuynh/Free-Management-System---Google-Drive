import 'dart:math';

import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/tong_quan_api.dart';
// TODO: chỉnh lại đường dẫn cho khớp vị trí thật của app_colors.dart /
// app_spacing.dart trong dự án (đang giả định cùng cấp với apis/ ở lib/configs/).
import '../../configs/app_colors.dart';
import '../../configs/app_spacing.dart';
import '../../utils/tong_quan_util.dart';
import '../../utils/time_util.dart';

/// Trang Tổng quan (dashboard trang chủ). State giữ cục bộ trong View,
/// tải 1 lần khi mở màn — giống pattern các list view khác trong app,
/// nhưng KHÔNG có search/filter/phân trang vì dashboard chỉ hiển thị
/// snapshot rút gọn (limit cố định), không phải danh sách đầy đủ.
///
/// Toàn bộ màu trong file này lấy từ AppColors / Theme.of(context) (áp
/// dụng theo AppTheme.light/dark đã khai báo) thay vì hex cứng, để khi
/// cần đổi bộ nhận diện chỉ phải sửa app_colors.dart. Các hằng số/hàm
/// thuần (map trạng thái, format ngày, avatar...) nằm ở tong_quan_util.dart.
class TongQuanView extends StatefulWidget {
  const TongQuanView({super.key});

  @override
  State<TongQuanView> createState() => _TongQuanViewState();
}

class _TongQuanViewState extends State<TongQuanView> {
  final _api = TongQuanApi(ApiRequestManager.instance);

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _albumDangXuLy = [];
  Map<String, dynamic> _soLuongTheoTrangThai = {};
  List<Map<String, dynamic>> _nhatKyHeThong = [];
  List<Map<String, dynamic>> _lichPhanCong = [];

  // TODO: lấy tên người dùng thật từ session/auth thay vì chuỗi tạm này.
  String _tenNguoiDung = '';

  @override
  void initState() {
    super.initState();
    _taiDashboard();
  }

  List<Map<String, dynamic>> _readList(dynamic node) {
    if (node is! Map) return const [];
    final raw = node['du_lieu'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _taiDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final body = await _api.dashboard(
        albumTrangThai: 'dang_xu_ly',
        albumLimit: 5,
        logLimit: 5,
        phanCongLimit: 4,
      );
      if (!mounted) return;

      final soLuongRaw = body['so_luong_album_theo_trang_thai'];
      setState(() {
        _albumDangXuLy = _readList(body['album_dang_xu_ly']);
        _soLuongTheoTrangThai =
            soLuongRaw is Map ? Map<String, dynamic>.from(soLuongRaw) : {};
        _nhatKyHeThong = _readList(body['nhat_ky_he_thong']);
        _lichPhanCong = _readList(body['lich_phan_cong']);
        _tenNguoiDung = body['ten_nguoi_dung']?.toString() ?? _tenNguoiDung;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  // TODO: xác nhận đúng route name thật cho các nút "Xem tất cả" (đang
  // giả định theo path bên React: /album, /log, /lich-phan-cong).
  void _xemTatCa(String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _albumDangXuLy.isEmpty && _nhatKyHeThong.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _taiDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          children: [
            _LoiChao(tenNguoiDung: _tenNguoiDung),
            SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              SizedBox(height: AppSpacing.md),
            ],
            _TienDoAlbumCard(
              soLuongTheoTrangThai: _soLuongTheoTrangThai,
              isLoading: _isLoading,
            ),
            SizedBox(height: AppSpacing.md),
            _AlbumDangXuLyCard(
              items: _albumDangXuLy,
              isLoading: _isLoading,
              onXemTatCa: () => _xemTatCa('/album'),
              onXemAlbum: (id) =>
                  Navigator.of(context).pushNamed('/album/detail/$id'),
            ),
            SizedBox(height: AppSpacing.md),
            _PhanCongCard(
              items: _lichPhanCong,
              isLoading: _isLoading,
              onXemTatCa: () => _xemTatCa('/lich-phan-cong'),
            ),
            SizedBox(height: AppSpacing.md),
            _NhatKyHeThongCard(
              items: _nhatKyHeThong,
              isLoading: _isLoading,
              onXemTatCa: () => _xemTatCa('/log'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LỜI CHÀO ĐẦU TRANG
// ============================================================
class _LoiChao extends StatelessWidget {
  const _LoiChao({required this.tenNguoiDung});
  final String tenNguoiDung;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tenNguoiDung.isEmpty ? 'Xin chào' : 'Xin chào, $tenNguoiDung',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Tổng quan tình hình hoạt động studio hôm nay',
          style: TextStyle(fontSize: 13.5, color: onSurfaceVariant),
        ),
      ],
    );
  }
}

// ============================================================
// THÀNH PHẦN DÙNG CHUNG
// ============================================================

/// Khung thẻ dùng chung cho mọi khối trong trang Tổng quan. Dùng thẳng
/// `Card` để thừa hưởng CardThemeData đã khai báo trong AppTheme (màu
/// nền AppColors.surface/surfaceDark, viền AppColors.border/borderDark,
/// bo góc AppSpacing.radiusMd) — tự đổi theo light/dark.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    this.onViewAll,
    this.leading,
  });

  final String title;
  final VoidCallback? onViewAll;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        if (onViewAll != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onViewAll,
            child: const Text(
              'Xem tất cả →',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _TieuDeIcon extends StatelessWidget {
  const _TieuDeIcon({this.color = AppColors.primary});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}

// ============================================================
// KHỐI 1: Tiến độ xử lý album (donut chart)
// ============================================================
class _TienDoAlbumCard extends StatelessWidget {
  const _TienDoAlbumCard({
    required this.soLuongTheoTrangThai,
    required this.isLoading,
  });

  final Map<String, dynamic> soLuongTheoTrangThai;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final donutData = trangThaiMap.entries.map((e) {
      final value = (soLuongTheoTrangThai[e.key] as num?)?.toDouble() ?? 0;
      return (
        key: e.key,
        value: value,
        label: e.value.label,
        color: e.value.color
      );
    }).toList();

    final tongSo = donutData.fold<double>(0, (sum, d) => sum + d.value);
    final coDuLieu = tongSo > 0 || !isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _CardHeader(
                title: 'Tiến độ xử lý album',
                leading: _TieuDeIcon(),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DonutChart(
                slices: donutData
                    .map((d) => (value: d.value, color: d.color))
                    .toList(),
                total: tongSo,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: !coDuLieu
                    ? Text(
                        'Chưa có dữ liệu',
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant, fontSize: 13),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in donutData)
                            _DonutLegendRow(
                              color: item.color,
                              label: item.label,
                              value: item.value.toInt(),
                              percent: tongSo > 0
                                  ? (item.value / tongSo * 100).round()
                                  : 0,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  final Color color;
  final String label;
  final int value;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.slices, required this.total});

  final List<({double value, Color color})> slices;
  final double total;

  @override
  Widget build(BuildContext context) {
    const size = 116.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _DonutChartPainter(
              slices: slices,
              strokeWidth: 14,
              mauNenRanh:
                  Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total.toInt().toString(),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                'Album',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.slices,
    required this.strokeWidth,
    required this.mauNenRanh,
  });

  final List<({double value, Color color})> slices;
  final double strokeWidth;
  final Color mauNenRanh;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = mauNenRanh
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final nonZero = slices.where((s) => s.value > 0).toList();
    final total = nonZero.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0 || nonZero.isEmpty) return;

    if (nonZero.length == 1) {
      final paint = Paint()
        ..color = nonZero.first.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    var startAngle = -pi / 2;
    for (final s in nonZero) {
      final sweep = (s.value / total) * 2 * pi;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.mauNenRanh != mauNenRanh;
  }
}

// ============================================================
// KHỐI 2: Album đang xử lý
// ============================================================
class _AlbumDangXuLyCard extends StatelessWidget {
  const _AlbumDangXuLyCard({
    required this.items,
    required this.isLoading,
    required this.onXemTatCa,
    required this.onXemAlbum,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final VoidCallback onXemTatCa;
  final ValueChanged<dynamic> onXemAlbum;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'Album đang xử lý', onViewAll: onXemTatCa),
          const SizedBox(height: 10),
          if (items.isEmpty && !isLoading)
            const _EmptyState(text: 'Không có album đang xử lý')
          else
            for (var i = 0; i < items.length; i++) ...[
              _AlbumTile(
                album: items[i],
                onTap: () => onXemAlbum(items[i]['id_album'] ?? items[i]['id']),
              ),
              if (i != items.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.onTap});
  final Map<String, dynamic> album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tongSo = (album['tong_so_yeu_cau_chinh_sua'] as num?)?.toInt() ?? 0;
    final dangCho = (album['so_yeu_cau_dang_cho_xu_ly'] as num?)?.toInt() ?? 0;
    final soLanMienPhi =
        (album['so_lan_chinh_sua_mien_phi'] as num?)?.toInt() ?? 0;
    final daXongHet = tongSo > 0 && dangCho == 0;

    final trangThaiKey = album['trang_thai']?.toString() ?? 'dang_xu_ly';
    final trangThai = trangThaiMap[trangThaiKey];
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Trước đây dùng AppColors.primaryLight.withOpacity(0.18) — hex
        // cố định nên ở dark mode bị pha ra màu xám xịt, khó nhìn.
        // Đổi sang colorScheme.primaryContainer (tự đổi
        // primaryLight ↔ primaryDark theo theme) để luôn ra tông ấm hợp
        // với nền, dù light hay dark.
        color: colorScheme.primaryContainer.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        // Trước đây AppColors.border cố định (chỉ đúng ở light) — đổi
        // sang colorScheme.outline để tự chuyển border/borderDark.
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TÊN ALBUM',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album['ten_album']?.toString() ?? '--',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trangThai != null) _TrangThaiBadge(info: trangThai),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ThongKeAlbumCot(
                  nhan: 'Ngày tạo',
                  giaTri: formatDate(album['created_at']?.toString()),
                ),
              ),
              _NganCotDoc(mau: colorScheme.outline),
              Expanded(
                child: _ThongKeAlbumCot(
                  nhan: 'Y/c đã chốt',
                  giaTri: '$dangCho',
                  mauGiaTri: daXongHet ? AppColors.success : null,
                ),
              ),
              _NganCotDoc(mau: colorScheme.outline),
              Expanded(
                child: _ThongKeAlbumCot(
                  nhan: 'Sửa miễn phí',
                  giaTri: '$soLanMienPhi lần',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Text('Xem chi tiết album',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              label: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrangThaiBadge extends StatelessWidget {
  const _TrangThaiBadge({required this.info});
  final TrangThaiInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: info.color),
          ),
          const SizedBox(width: 6),
          Text(
            info.label,
            style: TextStyle(
                color: info.color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ThongKeAlbumCot extends StatelessWidget {
  const _ThongKeAlbumCot(
      {required this.nhan, required this.giaTri, this.mauGiaTri});
  final String nhan;
  final String giaTri;
  final Color? mauGiaTri;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nhan,
          style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 3),
        Text(
          giaTri,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, color: mauGiaTri),
        ),
      ],
    );
  }
}

class _NganCotDoc extends StatelessWidget {
  const _NganCotDoc({required this.mau});
  final Color mau;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: mau,
    );
  }
}

// ============================================================
// KHỐI 3: Phân công gần đây
// ============================================================
class _PhanCongCard extends StatelessWidget {
  const _PhanCongCard({
    required this.items,
    required this.isLoading,
    required this.onXemTatCa,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final VoidCallback onXemTatCa;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'Phân công gần đây', onViewAll: onXemTatCa),
          const SizedBox(height: 10),
          if (items.isEmpty && !isLoading)
            const _EmptyState(text: 'Chưa có phân công nào')
          else
            for (var i = 0; i < items.length; i++) ...[
              _PhanCongTile(item: items[i]),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PhanCongTile extends StatelessWidget {
  const _PhanCongTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final seed = (item['tai_khoan_nhan_vien_id'] ?? '').toString();
    final idx = avatarIndex(seed);
    final tenAlbum = item['ten_album']?.toString() ?? '--';
    final tenNhanVien = item['nhan_vien_ho_ten']?.toString() ?? '--';
    final laNguoiBaoCao = item['la_nguoi_bao_cao'] == true;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: avatarPalette[idx],
            child: Text(
              layChuCaiDau(item['nhan_vien_ho_ten']?.toString()),
              style: TextStyle(
                color: avatarPaletteFg[idx],
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '$tenAlbum: $tenNhanVien',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppColors.primary,
                      ),
                    ),
                    if (laNguoiBaoCao)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          // Dùng primaryContainer thay vì primaryLight
                          // cố định để badge cũng tự đổi tông theo dark
                          // mode như phần album tile ở trên.
                          color: colorScheme.primaryContainer.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: colorScheme.primaryContainer),
                        ),
                        child: Text(
                          'Người báo cáo',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${formatNgayGio(item['thoi_gian_bat_dau']?.toString())}'
                        ' - '
                        '${formatNgayGio(item['thoi_gian_ket_thuc']?.toString())}',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// KHỐI 4: Nhật ký hệ thống (timeline)
// ============================================================
class _NhatKyHeThongCard extends StatelessWidget {
  const _NhatKyHeThongCard({
    required this.items,
    required this.isLoading,
    required this.onXemTatCa,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final VoidCallback onXemTatCa;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'Nhật ký hệ thống', onViewAll: onXemTatCa),
          const SizedBox(height: 6),
          if (items.isEmpty && !isLoading)
            const _EmptyState(text: 'Không có log nào')
          else
            for (var i = 0; i < items.length; i++)
              _LogTile(log: items[i], isLast: i == items.length - 1),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.isLast});
  final Map<String, dynamic> log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final hanhDong = log['hanh_dong']?.toString() ?? '';
    final ghiChu = log['ghi_chu']?.toString();
    final icon = hanhDongIcon[hanhDong] ?? Icons.circle;
    final mauNen =
        hanhDongMauNen[hanhDong] ?? Theme.of(context).colorScheme.outline;
    final duongKe =
        Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: mauNen),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: duongKe),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (ghiChu != null && ghiChu.isNotEmpty)
                        ? ghiChu
                        : moTaLog(log),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatNgayGio(log['created_at']?.toString()),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
