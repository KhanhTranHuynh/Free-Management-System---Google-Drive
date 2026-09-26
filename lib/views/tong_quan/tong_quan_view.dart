import 'dart:math';

import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/tong_quan_api.dart';

// ============================================================
// MAP TRẠNG THÁI / NHÃN — khớp TRANG_THAI_MAP, TEN_BANG_LABEL,
// HANH_DONG_LABEL, HANH_DONG_ICON bên React.
// ============================================================
class _TrangThaiInfo {
  const _TrangThaiInfo(this.label, this.color);
  final String label;
  final Color color;
}

const Map<String, _TrangThaiInfo> _trangThaiMap = {
  'chua_xu_ly': _TrangThaiInfo('Chưa xử lý', Color(0xFFF59E0B)),
  'dang_xu_ly': _TrangThaiInfo('Đang xử lý', Color(0xFF3B82F6)),
  'hoan_thanh': _TrangThaiInfo('Hoàn thành', Color(0xFF10B981)),
  'huy': _TrangThaiInfo('Đã huỷ', Color(0xFFF43F5E)),
};

const Map<String, String> _tenBangLabel = {
  'album': 'album',
  'yeu_cau_chinh_sua': 'yêu cầu chỉnh sửa',
  'tep_anh': 'tệp ảnh',
};

const Map<String, String> _hanhDongLabel = {
  'tao': 'đã tạo mới',
  'cap_nhat': 'đã cập nhật',
  'xoa': 'đã xoá',
  'chot_tat_ca_theo_album': 'đã chốt tất cả yêu cầu chỉnh sửa của',
};

const Map<String, String> _hanhDongIcon = {
  'tao': '⬆️',
  'cap_nhat': '✏️',
  'xoa': '❌',
  'chot_tat_ca_theo_album': '✅',
};

const Map<String, Color> _hanhDongIconBg = {
  'tao': Color(0xFFE0F2FE), // sky-50
  'cap_nhat': Color(0xFFFFFBEB), // amber-50
  'xoa': Color(0xFFFFF1F2), // rose-50
  'chot_tat_ca_theo_album': Color(0xFFECFDF5), // emerald-50
};

const Map<String, Color> _hanhDongIconFg = {
  'tao': Color(0xFF0284C7),
  'cap_nhat': Color(0xFFD97706),
  'xoa': Color(0xFFE11D48),
  'chot_tat_ca_theo_album': Color(0xFF059669),
};

/// nhat_ky_he_thong.ghi_chu hiện đang null -> tự build mô tả từ
/// ten_bang + hanh_dong, giống moTaLog() bên React.
String _moTaLog(Map<String, dynamic> log) {
  final hanhDongRaw = log['hanh_dong']?.toString() ?? '';
  final tenBangRaw = log['ten_bang']?.toString() ?? '';
  final hanhDong = _hanhDongLabel[hanhDongRaw] ?? hanhDongRaw;
  final banLabel = _tenBangLabel[tenBangRaw] ?? tenBangRaw;
  return 'Hệ thống $hanhDong $banLabel';
}

// ============================================================
// AVATAR — màu ổn định theo id (hash), khớp avatarClass() bên React.
// ============================================================
const List<Color> _avatarPalette = [
  Color(0xFFE0E7FF), // indigo-100
  Color(0xFFCCFBF1), // teal-100
  Color(0xFFFFEDD5), // orange-100
  Color(0xFFF3E8FF), // purple-100
  Color(0xFFCFFAFE), // cyan-100
];

const List<Color> _avatarPaletteFg = [
  Color(0xFF4338CA),
  Color(0xFF0F766E),
  Color(0xFFC2410C),
  Color(0xFF7E22CE),
  Color(0xFF0E7490),
];

int _avatarIndex(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash % _avatarPalette.length;
}

/// Lấy chữ cái đầu của 2 từ cuối trong họ tên (vd "Nguyễn Văn An" -> "VA"),
/// khớp layChuCaiDau() bên React.
String _layChuCaiDau(String? hoTen) {
  if (hoTen == null || hoTen.trim().isEmpty) return '?';
  final words = hoTen.trim().split(RegExp(r'\s+'));
  final lastTwo = words.length <= 2 ? words : words.sublist(words.length - 2);
  return lastTwo.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
}

// ============================================================
// FORMAT NGÀY GIỜ — thay cho dateHelper bên React.
// TODO: nếu app đã có helper format ngày dùng chung (vd package intl),
// thay 2 hàm này bằng helper đó để đồng nhất định dạng toàn app.
// ============================================================
String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '--';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '--';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}

String _formatNgayGio(String? iso) {
  if (iso == null || iso.isEmpty) return '--';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '--';
  final gio = '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
  return '$gio ${_formatDate(iso)}';
}

/// Trang Tổng quan (dashboard trang chủ). State giữ cục bộ trong View,
/// tải 1 lần khi mở màn — giống pattern các list view khác trong app,
/// nhưng KHÔNG có search/filter/phân trang vì dashboard chỉ hiển thị
/// snapshot rút gọn (limit cố định), không phải danh sách đầy đủ.
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

    return RefreshIndicator(
      onRefresh: _taiDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tổng quan',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          _AlbumDangXuLyCard(
            items: _albumDangXuLy,
            isLoading: _isLoading,
            onXemTatCa: () => _xemTatCa('/album'),
            onXemAlbum: (id) =>
                Navigator.of(context).pushNamed('/album/detail', arguments: id),
          ),
          const SizedBox(height: 16),
          _NhatKyHeThongCard(
            items: _nhatKyHeThong,
            isLoading: _isLoading,
            onXemTatCa: () => _xemTatCa('/log'),
          ),
          const SizedBox(height: 16),
          _TienDoAlbumCard(
            soLuongTheoTrangThai: _soLuongTheoTrangThai,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          _PhanCongCard(
            items: _lichPhanCong,
            isLoading: _isLoading,
            onXemTatCa: () => _xemTatCa('/lich-phan-cong'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Thành phần dùng chung: header có tiêu đề + nút "Xem tất cả"
// ============================================================
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    this.onViewAll,
  });

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('Xem tất cả →'),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).hintColor),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFE11D48))),
    );
  }
}

// ============================================================
// KHỐI 1: Album đang xử lý
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(title: 'Album đang xử lý', onViewAll: onXemTatCa),
            const SizedBox(height: 12),
            if (items.isEmpty && !isLoading)
              const _EmptyState(text: 'Không có album đang xử lý')
            else
              for (final album in items)
                _AlbumTile(
                  album: album,
                  onTap: () => onXemAlbum(album['id_album'] ?? album['id']),
                ),
          ],
        ),
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
    final highlightColor = daXongHet ? const Color(0xFF059669) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album['ten_album']?.toString() ?? '--',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ngày tạo: ${_formatDate(album['created_at']?.toString())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'YC chỉnh sửa đã chốt: $dangCho · '
                  'Số lần miễn phí: $soLanMienPhi',
                  style: TextStyle(fontSize: 12, color: highlightColor),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Xem')),
        ],
      ),
    );
  }
}

// ============================================================
// KHỐI 2: Nhật ký hệ thống (timeline)
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(title: 'Nhật ký hệ thống', onViewAll: onXemTatCa),
            const SizedBox(height: 12),
            if (items.isEmpty && !isLoading)
              const _EmptyState(text: 'Không có log nào')
            else
              for (var i = 0; i < items.length; i++)
                _LogTile(log: items[i], isLast: i == items.length - 1),
          ],
        ),
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
    final icon = _hanhDongIcon[hanhDong] ?? '•';
    final bg = _hanhDongIconBg[hanhDong] ?? Colors.grey.shade200;
    final fg = _hanhDongIconFg[hanhDong] ?? Colors.grey;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
                alignment: Alignment.center,
                child: Text(icon, style: TextStyle(color: fg, fontSize: 14)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: Colors.grey.shade200),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (ghiChu != null && ghiChu.isNotEmpty)
                        ? ghiChu
                        : _moTaLog(log),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatNgayGio(log['created_at']?.toString()),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
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

// ============================================================
// KHỐI 3: Tiến độ xử lý Album (donut chart)
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
    final donutData = soLuongTheoTrangThai.entries.map((e) {
      final info = _trangThaiMap[e.key];
      return (
        key: e.key,
        value: (e.value as num?)?.toDouble() ?? 0,
        label: info?.label ?? e.key,
        color: info?.color ?? const Color(0xFFCBD5E1),
      );
    }).toList();

    final tongSo = donutData.fold<double>(0, (sum, d) => sum + d.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Tiến độ xử lý album'),
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
                const SizedBox(width: 24),
                Expanded(
                  child: donutData.isEmpty && !isLoading
                      ? Text(
                          'Chưa có dữ liệu',
                          style: TextStyle(color: Theme.of(context).hintColor),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(color: Theme.of(context).hintColor)),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Donut chart vẽ bằng CustomPainter — thay cho SVG path bên React
/// (describeArc/polarToCartesian). Vẽ từng lát bằng drawArc nối liền
/// nhau quanh vòng tròn, bắt đầu từ vị trí 12h.
class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.slices, required this.total});

  final List<({double value, Color color})> slices;
  final double total;

  @override
  Widget build(BuildContext context) {
    const size = 140.0;
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
              strokeWidth: 16,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total.toInt().toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Album',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.slices, required this.strokeWidth});

  final List<({double value, Color color})> slices;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Nền rãnh phía sau.
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final nonZero = slices.where((s) => s.value > 0).toList();
    final total = nonZero.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0 || nonZero.isEmpty) return;

    // Chỉ 1 trạng thái có dữ liệu -> vòng tròn kín.
    if (nonZero.length == 1) {
      final paint = Paint()
        ..color = nonZero.first.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    var startAngle = -pi / 2; // bắt đầu từ 12h, khớp bản React
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
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ============================================================
// KHỐI 4: Phân công gần đây
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(title: 'Phân công gần đây', onViewAll: onXemTatCa),
            const SizedBox(height: 12),
            if (items.isEmpty && !isLoading)
              const _EmptyState(text: 'Chưa có phân công nào')
            else
              for (final pc in items) _PhanCongTile(item: pc),
          ],
        ),
      ),
    );
  }
}

class _PhanCongTile extends StatelessWidget {
  const _PhanCongTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seed = (item['tai_khoan_nhan_vien_id'] ?? '').toString();
    final idx = _avatarIndex(seed);
    final tenAlbum = item['ten_album']?.toString() ?? '--';
    final tenNhanVien = item['nhan_vien_ho_ten']?.toString() ?? '--';
    final laNguoiBaoCao = item['la_nguoi_bao_cao'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _avatarPalette[idx],
            child: Text(
              _layChuCaiDau(item['nhan_vien_ho_ten']?.toString()),
              style: TextStyle(
                color: _avatarPaletteFg[idx],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(text: tenAlbum),
                          TextSpan(
                            text: ': $tenNhanVien',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (laNguoiBaoCao)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'Người báo cáo',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNgayGio(item['thoi_gian_bat_dau']?.toString())}'
                  ' - '
                  '${_formatNgayGio(item['thoi_gian_ket_thuc']?.toString())}',
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
