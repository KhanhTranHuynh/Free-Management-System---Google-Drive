import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// Helpers ngày tháng (giá trị model luôn là chuỗi ISO "yyyy-MM-dd")
// ============================================================

final RegExp _isoRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime? _parseIso(String? iso) {
  if (iso == null) return null;
  final m = _isoRe.firstMatch(iso);
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

String _toIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _toDmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDate(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

/// Parse 8 chữ số ddMMyyyy -> DateTime (null nếu không hợp lệ).
DateTime? _parseDigits(String digits) {
  if (digits.length != 8) return null;
  final day = int.parse(digits.substring(0, 2));
  final month = int.parse(digits.substring(2, 4));
  final year = int.parse(digits.substring(4, 8));
  final dt = DateTime(year, month, day);
  if (dt.year != year || dt.month != month || dt.day != day) return null;
  return dt;
}

/// Tự chèn dấu "/" khi gõ: 12122026 -> 12/12/2026 (tối đa 8 chữ số).
class _DateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ============================================================
// DatePickerField
// ============================================================

/// Ô chọn ngày (dd/MM/yyyy) + lịch popup. Port từ DatePicker.jsx.
///
/// - `value` / `onChanged`: chuỗi ISO "yyyy-MM-dd" (null = chưa chọn).
/// - `min` / `max`: chuỗi ISO giới hạn khoảng chọn.
/// - `disabledDates`: danh sách ISO bị khoá; hoặc `isDateDisabled` (hàm).
/// - `selectOnly`: chỉ cho chọn bằng lịch, không gõ tay.
/// - `selectedColor`: màu ngày đang chọn (bên React là
///   config.MAU_SAC_MAC_DINH) — truyền AppColors.primary vào đây.
class DatePickerField extends StatefulWidget {
  const DatePickerField({
    super.key,
    this.value,
    this.onChanged,
    this.onInvalidInput,
    this.min,
    this.max,
    this.disabledDates = const [],
    this.isDateDisabled,
    this.label = '',
    this.placeholder = 'dd/mm/yyyy',
    this.disabled = false,
    this.clearable = true,
    this.readOnly = false,
    this.selectOnly = false,
    this.error,
    this.weekStartsOnMonday = true,
    this.selectedColor,
  });

  final String? value;
  final ValueChanged<String?>? onChanged;
  final ValueChanged<String>? onInvalidInput;
  final String? min;
  final String? max;
  final List<String> disabledDates;
  final bool Function(DateTime date)? isDateDisabled;
  final String label;
  final String placeholder;
  final bool disabled;
  final bool clearable;
  final bool readOnly;
  final bool selectOnly;
  final String? error;
  final bool weekStartsOnMonday;
  final Color? selectedColor;

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  DateTime? _selected;
  String? _localError;

  DateTime? get _minDate => _parseIso(widget.min);
  DateTime? get _maxDate => _parseIso(widget.max);

  bool _isDisabled(DateTime date) {
    final day = _dateOnly(date);
    final minVal = _minDate == null ? null : _dateOnly(_minDate!);
    final maxVal = _maxDate == null ? null : _dateOnly(_maxDate!);
    if (minVal != null && day.isBefore(minVal)) return true;
    if (maxVal != null && day.isAfter(maxVal)) return true;
    if (widget.disabledDates.contains(_toIso(day))) return true;
    final fn = widget.isDateDisabled;
    if (fn != null) {
      try {
        return fn(day);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _selected = _parseIso(widget.value);
    _controller = TextEditingController(
        text: _selected == null ? '' : _toDmy(_selected!));
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selected = _parseIso(widget.value);
      _controller.text = _selected == null ? '' : _toDmy(_selected!);
      _localError = null;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _validateAndCommit();
  }

  void _emit(String? iso) => widget.onChanged?.call(iso);

  void _commit(DateTime date) {
    setState(() {
      _selected = date;
      _localError = null;
      _controller.text = _toDmy(date);
    });
    _emit(_toIso(date));
  }

  void _clear() {
    if (widget.readOnly) return;
    setState(() {
      _selected = null;
      _localError = null;
      _controller.clear();
    });
    _emit(null);
  }

  void _baoLoi(String msg) {
    setState(() => _localError = msg);
    widget.onInvalidInput?.call(msg);
  }

  /// Tương đương onInputBlur bên React.
  void _validateAndCommit() {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      if (widget.value != null) _clear();
      return;
    }

    if (digits.length < 8) {
      final missing = <String>[];
      if (digits.length < 2) missing.add('ngày');
      if (digits.length < 4) missing.add('tháng');
      if (digits.length < 8) missing.add('năm');
      final msg = missing.length == 1
          ? 'Thiếu ${missing[0]}'
          : missing.length == 2
              ? 'Thiếu ${missing[0]} và ${missing[1]}'
              : 'Thiếu ${missing.join(', ')}';
      _baoLoi(msg);
      return;
    }

    final parsed = _parseDigits(digits);
    if (parsed == null || _isDisabled(parsed)) {
      _baoLoi('Ngày không hợp lệ');
      return;
    }
    _commit(parsed);
  }

  Future<void> _openCalendar() async {
    if (widget.disabled || widget.readOnly) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final res = await showDialog<_CalendarResult>(
      context: context,
      builder: (_) => _CalendarDialog(
        initial: _selected,
        isDisabled: _isDisabled,
        weekStartsOnMonday: widget.weekStartsOnMonday,
        selectedColor:
            widget.selectedColor ?? Theme.of(context).colorScheme.primary,
        clearable: widget.clearable,
      ),
    );
    if (res == null || !mounted) return;
    if (res.clear) {
      _clear();
    } else if (res.date != null) {
      _commit(res.date!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorText = (_localError != null && _localError!.isNotEmpty)
        ? _localError
        : widget.error;
    final coNutXoa = widget.clearable &&
        !widget.disabled &&
        !widget.readOnly &&
        _controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.label,
              style:
                  TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !widget.disabled,
          readOnly: widget.readOnly || widget.selectOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [_DateMaskFormatter()],
          onChanged: (_) => setState(() => _localError = null),
          onSubmitted: (_) => _validateAndCommit(),
          onTap: widget.selectOnly ? _openCalendar : null,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            isDense: true,
            errorText: errorText,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coNutXoa)
                  IconButton(
                    tooltip: 'Xóa ngày',
                    visualDensity: VisualDensity.compact,
                    onPressed: _clear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                if (!widget.disabled && !widget.readOnly)
                  IconButton(
                    tooltip: 'Mở lịch',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openCalendar,
                    icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Popup lịch
// ============================================================

class _CalendarResult {
  const _CalendarResult({this.date, this.clear = false});
  final DateTime? date;
  final bool clear;
}

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({
    required this.initial,
    required this.isDisabled,
    required this.weekStartsOnMonday,
    required this.selectedColor,
    required this.clearable,
  });

  final DateTime? initial;
  final bool Function(DateTime) isDisabled;
  final bool weekStartsOnMonday;
  final Color selectedColor;
  final bool clearable;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _view; // ngày 1 của tháng đang xem
  bool _pickerOpen = false;
  late int _pickerYear;

  @override
  void initState() {
    super.initState();
    final base = widget.initial ?? DateTime.now();
    _view = DateTime(base.year, base.month, 1);
    _pickerYear = _view.year;
  }

  void _doiThang(int delta) {
    setState(() {
      _view = DateTime(_view.year, _view.month + delta, 1);
      _pickerYear = _view.year;
    });
  }

  void _doiNam(int year) {
    setState(() {
      _pickerYear = year;
      _view = DateTime(year, _view.month, 1);
    });
  }

  void _chonThang(int month) {
    setState(() {
      _view = DateTime(_pickerYear, month, 1);
      _pickerOpen = false;
    });
  }

  DateTime get _gridStart {
    final first = DateTime(_view.year, _view.month, 1);
    final offset = widget.weekStartsOnMonday
        ? first.weekday - 1 // Mon=1..Sun=7
        : first.weekday % 7; // Sun=0
    return DateTime(first.year, first.month, first.day - offset);
  }

  List<String> get _thuTrongTuan {
    const t2 = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return widget.weekStartsOnMonday
        ? t2
        : ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ----- thanh tháng/năm -----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: () => _doiThang(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _pickerOpen = !_pickerOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tháng ${_view.month}, ${_view.year}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Icon(
                            _pickerOpen
                                ? Icons.arrow_drop_up_rounded
                                : Icons.arrow_drop_down_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: () => _doiThang(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),

              if (_pickerOpen) _buildMonthYearPicker(colorScheme),

              // ----- tiêu đề thứ -----
              Row(
                children: [
                  for (final w in _thuTrongTuan)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Center(
                          child: Text(
                            w,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // ----- lưới 6 tuần -----
              for (var w = 0; w < 6; w++)
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      _buildCell(
                        DateTime(_gridStart.year, _gridStart.month,
                            _gridStart.day + w * 7 + i),
                        colorScheme,
                      ),
                  ],
                ),

              const Divider(height: 20),

              // ----- chân: Xóa / Hôm nay -----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.clearable)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context)
                          .pop(const _CalendarResult(clear: true)),
                      child: const Text('Xóa'),
                    )
                  else
                    const SizedBox.shrink(),
                  OutlinedButton(
                    onPressed: () {
                      final today = _dateOnly(DateTime.now());
                      if (widget.isDisabled(today)) return;
                      Navigator.of(context).pop(_CalendarResult(date: today));
                    },
                    child: const Text('Hôm nay'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthYearPicker(ColorScheme colorScheme) {
    final years = List<int>.generate(21, (i) => _pickerYear - 10 + i);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Năm trước',
                visualDensity: VisualDensity.compact,
                onPressed: () => _doiNam(_pickerYear - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Center(
                  child: DropdownButton<int>(
                    value: _pickerYear,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (y) {
                      if (y != null) _doiNam(y);
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Năm sau',
                visualDensity: VisualDensity.compact,
                onPressed: () => _doiNam(_pickerYear + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              for (var m = 1; m <= 12; m++)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _chonThang(m),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m == _view.month
                          ? widget.selectedColor.withOpacity(0.15)
                          : colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: m == _view.month
                            ? widget.selectedColor
                            : colorScheme.outline,
                      ),
                    ),
                    child: Text('Thg $m', style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(DateTime d, ColorScheme colorScheme) {
    final disabled = widget.isDisabled(d);
    final inMonth = d.month == _view.month;
    final selected = _sameDate(d, widget.initial);
    final today = _sameDate(d, DateTime.now());

    final selectedFg =
        ThemeData.estimateBrightnessForColor(widget.selectedColor) ==
                Brightness.dark
            ? Colors.white
            : Colors.black87;

    Color fg;
    if (selected && !disabled) {
      fg = selectedFg;
    } else if (disabled) {
      fg = colorScheme.onSurface.withOpacity(0.3);
    } else if (!inMonth) {
      fg = colorScheme.onSurfaceVariant.withOpacity(0.6);
    } else {
      fg = colorScheme.onSurface;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: disabled
              ? null
              : () => Navigator.of(context).pop(_CalendarResult(date: d)),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected && !disabled ? widget.selectedColor : null,
              borderRadius: BorderRadius.circular(8),
              border: today && !selected
                  ? Border.all(color: colorScheme.outline)
                  : null,
            ),
            child: Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 14,
                color: fg,
                decoration: disabled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
