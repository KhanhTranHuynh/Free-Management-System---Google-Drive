import 'package:flutter/material.dart';

import '../configs/app_colors.dart';

enum CalendarVariant { primary, warning, neutral }

enum CalendarViewMode { thang, tuan, ngay, lichBieu }

/// Tương ứng event của CalendarCustom.jsx.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.variant = CalendarVariant.neutral,
    this.data,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final CalendarVariant variant;

  /// Dữ liệu gốc (extendedProps).
  final Map<String, dynamic>? data;
}

// ---------------------------------------------------------------------------
// Hằng số + helper ngày
// ---------------------------------------------------------------------------
const _tenThu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const _tenThuDayDu = [
  'Chủ nhật',
  'Thứ hai',
  'Thứ ba',
  'Thứ tư',
  'Thứ năm',
  'Thứ sáu',
  'Thứ bảy'
];
const double _hourH = 48;
const double _gioMacDinhCuon = 7;
const int _phutToiThieu = 30;
const double _cotGioW = 52;

String _p2(int n) => n.toString().padLeft(2, '0');
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool _cungNgay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
DateTime _addMonths(DateTime d, int n) => DateTime(d.year, d.month + n, 1);
DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);
// Tuần bắt đầu Thứ 2 (DateTime.weekday: Thứ 2 = 1).
DateTime _startOfWeek(DateTime d) => _addDays(_dateOnly(d), -(d.weekday - 1));
List<DateTime> _luoiThang(DateTime m) {
  final start = _startOfWeek(_startOfMonth(m));
  return List.generate(42, (i) => _addDays(start, i));
}

String _gio(DateTime d) => '${_p2(d.hour)}:${_p2(d.minute)}';
String _ngayNgan(DateTime d) => '${_p2(d.day)}/${_p2(d.month)}';
String _thuDayDu(DateTime d) => _tenThuDayDu[d.weekday % 7];

({DateTime tu, DateTime den}) _tinhKhoang(CalendarViewMode mode, DateTime moc) {
  switch (mode) {
    case CalendarViewMode.tuan:
      final tu = _startOfWeek(moc);
      return (tu: tu, den: _addDays(tu, 6));
    case CalendarViewMode.ngay:
      final d = _dateOnly(moc);
      return (tu: d, den: d);
    case CalendarViewMode.lichBieu:
      return (tu: _startOfMonth(moc), den: _endOfMonth(moc));
    case CalendarViewMode.thang:
      final l = _luoiThang(moc);
      return (tu: l.first, den: l.last);
  }
}

// ---------------------------------------------------------------------------
// Event chuẩn hoá + bố cục làn (lane) cho lưới giờ
// ---------------------------------------------------------------------------
class _Ev {
  _Ev(this.ev)
      : start = ev.start,
        end = ev.end ?? ev.start,
        startDay = _dateOnly(ev.start),
        endDay = _dateOnly(ev.end ?? ev.start);
  final CalendarEvent ev;
  final DateTime start;
  final DateTime end;
  final DateTime startDay;
  final DateTime endDay;
}

class _Placed {
  _Placed(this.ev, this.startMin, this.endMin,
      [this.lane = 0, this.soLane = 1]);
  final _Ev ev;
  final double startMin;
  final double endMin;
  int lane;
  int soLane;
}

List<_Placed> _boCucNgay(DateTime day, List<_Ev> events) {
  final dayStart = day;
  final dayEnd = _addDays(day, 1);

  final items = <_Placed>[];
  for (final e in events) {
    final s = e.start, en = e.end;
    if (!(s.isBefore(dayEnd) &&
        (en.isAfter(dayStart) || !s.isBefore(dayStart)))) {
      continue;
    }
    final sc = s.isBefore(dayStart) ? dayStart : s;
    final ec = en.isAfter(dayEnd) ? dayEnd : en;
    final startMin = sc.difference(dayStart).inSeconds / 60;
    final endRaw = ec.difference(dayStart).inSeconds / 60;
    final endMin =
        (endRaw > startMin + _phutToiThieu ? endRaw : startMin + _phutToiThieu)
            .clamp(0, 1440)
            .toDouble();
    items.add(_Placed(e, startMin, endMin));
  }
  items.sort((a, b) {
    final c = a.startMin.compareTo(b.startMin);
    return c != 0 ? c : b.endMin.compareTo(a.endMin);
  });

  final ketQua = <_Placed>[];
  var cum = <_Placed>[];
  var cumEnd = -1.0;
  var laneEnds = <double>[];

  void dongCum() {
    if (cum.isEmpty) return;
    var soLane = 1;
    for (final c in cum) {
      if (c.lane + 1 > soLane) soLane = c.lane + 1;
    }
    for (final c in cum) {
      c.soLane = soLane;
      ketQua.add(c);
    }
    cum = [];
  }

  for (final it in items) {
    if (it.startMin >= cumEnd) {
      dongCum();
      laneEnds = [];
      cumEnd = -1;
    }
    var lane = laneEnds.indexWhere((end) => end <= it.startMin);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(it.endMin);
    } else {
      laneEnds[lane] = it.endMin;
    }
    it.lane = lane;
    cum.add(it);
    if (it.endMin > cumEnd) cumEnd = it.endMin;
  }
  dongCum();
  return ketQua;
}

Color _mauEvent(BuildContext context, CalendarVariant v) {
  switch (v) {
    case CalendarVariant.primary:
      return AppColors.primary;
    case CalendarVariant.warning:
      return Colors.amber.shade700;
    case CalendarVariant.neutral:
      return Theme.of(context).colorScheme.outline;
  }
}

// ===========================================================================
// CalendarCustom
// ===========================================================================
class CalendarCustom extends StatefulWidget {
  const CalendarCustom({
    super.key,
    this.initialDate,
    this.events = const [],
    this.onDatesSet,
    this.onDateTap,
    this.onEventTap,
    this.maxEventsPerDay = 3,
    this.loading = false,
    this.initialView = CalendarViewMode.thang,
  });

  final DateTime? initialDate;
  final List<CalendarEvent> events;

  /// Bắn khoảng ngày đang hiển thị (kể cả lần đầu) — như datesSet.
  final void Function(DateTime tu, DateTime den)? onDatesSet;
  final ValueChanged<DateTime>? onDateTap;
  final ValueChanged<CalendarEvent>? onEventTap;
  final int maxEventsPerDay;
  final bool loading;
  final CalendarViewMode initialView;

  @override
  State<CalendarCustom> createState() => _CalendarCustomState();
}

class _CalendarCustomState extends State<CalendarCustom> {
  late DateTime _moc = _dateOnly(widget.initialDate ?? DateTime.now());
  late CalendarViewMode _mode = widget.initialView;
  DateTime? _lastTu;
  DateTime? _lastDen;

  static const _cheDo = [
    (CalendarViewMode.thang, 'Tháng'),
    (CalendarViewMode.tuan, 'Tuần'),
    (CalendarViewMode.ngay, 'Ngày'),
    (CalendarViewMode.lichBieu, 'Lịch biểu'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _baoKhoang());
  }

  ({DateTime tu, DateTime den}) get _khoang => _tinhKhoang(_mode, _moc);

  void _baoKhoang() {
    if (!mounted) return;
    final k = _khoang;
    if (_lastTu != null &&
        _cungNgay(_lastTu!, k.tu) &&
        _cungNgay(_lastDen!, k.den)) {
      return;
    }
    _lastTu = k.tu;
    _lastDen = k.den;
    widget.onDatesSet?.call(k.tu, k.den);
  }

  void _set(VoidCallback fn) {
    setState(fn);
    WidgetsBinding.instance.addPostFrameCallback((_) => _baoKhoang());
  }

  List<_Ev> get _evs {
    final list = widget.events.map(_Ev.new).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  void _dichChuyen(int huong) => _set(() {
        switch (_mode) {
          case CalendarViewMode.tuan:
            _moc = _addDays(_moc, 7 * huong);
          case CalendarViewMode.ngay:
            _moc = _addDays(_moc, huong);
          default:
            _moc = _addMonths(_moc, huong);
        }
      });

  void _veHomNay() => _set(() => _moc = _dateOnly(DateTime.now()));

  void _doiCheDo(CalendarViewMode m) {
    if (m == _mode) return;
    _set(() {
      final now = DateTime.now();
      if (now.year == _moc.year && now.month == _moc.month) {
        _moc = _dateOnly(now);
      }
      _mode = m;
    });
  }

  void _chonNgayXemChiTiet(DateTime d) => _set(() {
        _moc = _dateOnly(d);
        _mode = CalendarViewMode.ngay;
      });

  String get _tieuDe {
    final k = _khoang;
    switch (_mode) {
      case CalendarViewMode.tuan:
        return '${_ngayNgan(k.tu)} – ${_ngayNgan(k.den)}/${k.den.year}';
      case CalendarViewMode.ngay:
        return '${_thuDayDu(_moc)}, ${_ngayNgan(_moc)}/${_moc.year}';
      default:
        return 'Tháng ${_moc.month} ${_moc.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final evs = _evs;
    final k = _khoang;
    final trongKhoang = evs
        .where((e) => !e.endDay.isBefore(k.tu) && !e.startDay.isAfter(k.den))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ----- Thanh điều hướng -----
        Row(
          children: [
            _NutVuong(icon: Icons.chevron_left, onTap: () => _dichChuyen(-1)),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: _veHomNay,
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Hôm nay'),
            ),
            const SizedBox(width: 6),
            _NutVuong(icon: Icons.chevron_right, onTap: () => _dichChuyen(1)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _tieuDe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (m, nhan) in _cheDo)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(nhan),
                    selected: _mode == m,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    backgroundColor: cs.surfaceContainerHigh,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _mode == m ? Colors.white : cs.onSurface,
                    ),
                    onSelected: (_) => _doiCheDo(m),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),

        switch (_mode) {
          CalendarViewMode.thang => _buildThang(evs),
          CalendarViewMode.tuan => _LuoiGio(
              days: List.generate(7, (i) => _addDays(k.tu, i)),
              events: trongKhoang,
              minWidth: 720,
              onChonNgay: _chonNgayXemChiTiet,
              onDateTap: widget.onDateTap,
              onEventTap: widget.onEventTap,
            ),
          CalendarViewMode.ngay => _LuoiGio(
              days: [k.tu],
              events: trongKhoang,
              minWidth: 0,
              onDateTap: widget.onDateTap,
              onEventTap: widget.onEventTap,
            ),
          CalendarViewMode.lichBieu => _buildLichBieu(trongKhoang, k.tu),
        },
      ],
    );
  }

  // ----- Tháng -----
  Widget _buildThang(List<_Ev> evs) {
    final cs = Theme.of(context).colorScheme;
    final luoi = _luoiThang(_moc);
    final homNay = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: cs.surfaceContainerHigh,
            child: Row(
              children: [
                for (final t in _tenThu)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < 6; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _oNgay(luoi[r * 7 + c], evs, homNay, cs)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _oNgay(DateTime day, List<_Ev> evs, DateTime homNay, ColorScheme cs) {
    final ds = evs
        .where((e) => !day.isBefore(e.startDay) && !day.isAfter(e.endDay))
        .toList();
    final khacThang = day.month != _moc.month;
    final laHomNay = _cungNgay(day, homNay);
    final hienThi = ds.take(widget.maxEventsPerDay).toList();
    final conLai = ds.length - hienThi.length;

    return InkWell(
      onTap: () => widget.onDateTap?.call(day),
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: khacThang
              ? cs.surfaceContainerHigh.withOpacity(0.4)
              : Colors.transparent,
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
            left: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _chonNgayXemChiTiet(day),
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: laHomNay ? AppColors.primary : null,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: laHomNay ? FontWeight.w700 : FontWeight.w500,
                      color: laHomNay
                          ? Colors.white
                          : khacThang
                              ? cs.onSurfaceVariant.withOpacity(0.5)
                              : cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            for (final e in hienThi)
              GestureDetector(
                onTap: () => widget.onEventTap?.call(e.ev),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: _mauEvent(context, e.ev.variant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.ev.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Colors.white),
                  ),
                ),
              ),
            if (conLai > 0)
              GestureDetector(
                onTap: () => _chonNgayXemChiTiet(day),
                child: Text('+$conLai khác',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }

  // ----- Lịch biểu -----
  Widget _buildLichBieu(List<_Ev> trongKhoang, DateTime tuNgay) {
    final cs = Theme.of(context).colorScheme;
    final homNay = DateTime.now();

    final map = <DateTime, List<_Ev>>{};
    for (final e in trongKhoang) {
      final ngay = e.startDay.isBefore(tuNgay) ? tuNgay : e.startDay;
      (map[ngay] ??= []).add(e);
    }
    final nhom = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    if (nhom.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Không có phân công nào trong tháng này.',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < nhom.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _cungNgay(nhom[i].key, homNay)
                                ? AppColors.primary
                                : null,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${nhom[i].key.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _cungNgay(nhom[i].key, homNay)
                                  ? Colors.white
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(_thuDayDu(nhom[i].key),
                            style: TextStyle(
                                fontSize: 10.5, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in nhom[i].value) _dongLichBieu(e, cs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dongLichBieu(_Ev e, ColorScheme cs) {
    final gio =
        e.ev.end != null ? '${_gio(e.start)} – ${_gio(e.end)}' : _gio(e.start);
    final nhieuNgay = !_cungNgay(e.startDay, e.endDay);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => widget.onEventTap?.call(e.ev),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _mauEvent(context, e.ev.variant),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.ev.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  Text(
                    nhieuNgay ? '$gio (đến ${_ngayNgan(e.endDay)})' : gio,
                    style:
                        TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
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

class _NutVuong extends StatelessWidget {
  const _NutVuong({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: cs.onSurface),
        ),
      ),
    );
  }
}

// ===========================================================================
// Lưới giờ dùng chung cho Tuần (7 cột) và Ngày (1 cột)
// ===========================================================================
class _LuoiGio extends StatefulWidget {
  const _LuoiGio({
    required this.days,
    required this.events,
    required this.minWidth,
    this.onChonNgay,
    this.onDateTap,
    this.onEventTap,
  });

  final List<DateTime> days;
  final List<_Ev> events;
  final double minWidth;
  final ValueChanged<DateTime>? onChonNgay;
  final ValueChanged<DateTime>? onDateTap;
  final ValueChanged<CalendarEvent>? onEventTap;

  @override
  State<_LuoiGio> createState() => _LuoiGioState();
}

class _LuoiGioState extends State<_LuoiGio> {
  // Lần đầu mở cuộn tới 07:00.
  final _cuon = ScrollController(initialScrollOffset: _gioMacDinhCuon * _hourH);

  @override
  void dispose() {
    _cuon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final homNay = DateTime.now();
    final phutHienTai = homNay.hour * 60 + homNay.minute;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, c) {
        final width =
            c.maxWidth < widget.minWidth ? widget.minWidth : c.maxWidth;
        final noiDung = SizedBox(
          width: width,
          child: Column(
            children: [
              // Hàng tiêu đề ngày
              Container(
                color: cs.surfaceContainerHigh,
                child: Row(
                  children: [
                    const SizedBox(width: _cotGioW),
                    for (final day in widget.days)
                      Expanded(child: _tieuDeNgay(day, homNay, cs)),
                  ],
                ),
              ),
              // Thân lưới giờ
              SizedBox(
                height: 560,
                child: SingleChildScrollView(
                  controller: _cuon,
                  child: SizedBox(
                    height: _hourH * 24,
                    child: Row(
                      children: [
                        SizedBox(
                          width: _cotGioW,
                          child: Stack(
                            children: [
                              for (var h = 1; h < 24; h++)
                                Positioned(
                                  top: h * _hourH - 7,
                                  right: 6,
                                  child: Text('${_p2(h)}:00',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: cs.onSurfaceVariant)),
                                ),
                            ],
                          ),
                        ),
                        for (final day in widget.days)
                          Expanded(
                              child: _cotNgay(day, homNay, phutHienTai, cs)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return width > c.maxWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: noiDung)
            : noiDung;
      }),
    );
  }

  Widget _tieuDeNgay(DateTime day, DateTime homNay, ColorScheme cs) {
    final laHomNay = _cungNgay(day, homNay);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          Text(_tenThu[day.weekday - 1],
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 3),
          GestureDetector(
            onTap: widget.onChonNgay == null
                ? null
                : () => widget.onChonNgay!(day),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: laHomNay ? AppColors.primary : null,
                shape: BoxShape.circle,
              ),
              child: Text('${day.day}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: laHomNay ? FontWeight.w700 : FontWeight.w500,
                      color: laHomNay ? Colors.white : cs.onSurface)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cotNgay(
      DateTime day, DateTime homNay, int phutHienTai, ColorScheme cs) {
    final laHomNay = _cungNgay(day, homNay);
    final bocuc = _boCucNgay(day, widget.events);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onDateTap?.call(day),
      child: Container(
        decoration: BoxDecoration(
          color: laHomNay ? AppColors.primary.withOpacity(0.05) : null,
          border: Border(left: BorderSide(color: cs.outlineVariant)),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var h = 0; h < 24; h++)
                Positioned(
                  top: h * _hourH,
                  left: 0,
                  right: 0,
                  child: Divider(
                      height: 1, color: cs.outlineVariant.withOpacity(0.5)),
                ),
              if (laHomNay)
                Positioned(
                  top: phutHienTai / 60 * _hourH,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: Colors.red),
                ),
              for (final p in bocuc)
                Positioned(
                  top: p.startMin / 60 * _hourH,
                  height: ((p.endMin - p.startMin) / 60 * _hourH - 2)
                      .clamp(20, double.infinity),
                  left: p.lane / p.soLane * w + 2,
                  width: w / p.soLane - 4,
                  child: GestureDetector(
                    onTap: () => widget.onEventTap?.call(p.ev.ev),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: _mauEvent(context, p.ev.ev.variant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.ev.ev.end != null
                                ? '${_gio(p.ev.start)} – ${_gio(p.ev.end)}'
                                : _gio(p.ev.start),
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 9.5, color: Colors.white70),
                          ),
                          Flexible(
                            child: Text(
                              p.ev.ev.title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
