import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Các kiểu input được hỗ trợ — tương ứng các "mode" của component
/// `Textinput` bên bản React (phone / email / money / number / soLuong /
/// mat_khau|password). Thêm biến thể nào thì bổ sung case tương ứng bên dưới.
enum AppTextInputType {
  text,
  email,
  phone,
  password,
  money,
  number,
  soLuong,
}

/// Input dùng chung cho toàn app — bản Dart hoá của component `Textinput`
/// bên React.
///
/// Bản này giữ nguyên toàn bộ logic (validate, format tiền, format số điện
/// thoại, xử lý IME tiếng Việt...) của `AppTextInput`, chỉ thay phần UI
/// (`InputDecoration`) bằng kiểu bo tròn, có nền (filled) và đổi màu viền
/// theo trạng thái — lấy cảm hứng từ `AppTextField`, để trông hiện đại và
/// nhất quán hơn giữa các trạng thái enabled / focus / error / disabled.
class AppTextInput extends StatefulWidget {
  const AppTextInput({
    super.key,
    required this.label,
    this.type = AppTextInputType.text,
    this.controller,
    this.initialValue,
    this.hint,
    this.required = false,
    this.requiredMessage,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.prefixIcon,
    this.errorText,
    this.helperText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
    this.minPasswordLength = 6,
    this.maxPasswordLength = 50,
  });

  /// Nhãn hiển thị (label nổi). Nếu [required] = true, tự thêm dấu "*".
  final String label;
  final AppTextInputType type;

  /// Tự tạo controller nội bộ nếu không truyền vào.
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;

  final bool required;
  final String? requiredMessage;

  final bool enabled;
  final bool readOnly;
  final bool autofocus;

  /// Nhận cả `Widget` (icon tuỳ biến, badge...) lẫn `IconData` (dùng nhanh
  /// như bên `AppTextField`) — xem `_resolvePrefixIcon()`.
  final Object? prefixIcon;

  /// Lỗi áp từ bên ngoài (vd lỗi server trả về) — luôn được ưu tiên hiển
  /// thị trước lỗi tự validate nội bộ.
  final String? errorText;
  final String? helperText;

  /// Validate tuỳ biến thêm, chạy SAU các rule mặc định theo [type].
  /// Nhận vào giá trị "thô" (đã bỏ ký tự định dạng với money/phone/number).
  final String? Function(String rawValue)? validator;

  /// Trả về giá trị "thô": money/phone/number/soLuong trả số đã bỏ định
  /// dạng (vd "1000000" thay vì "1,000,000"); các loại khác trả nguyên văn.
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final TextInputAction? textInputAction;
  final int? maxLength;
  final int minPasswordLength;
  final int maxPasswordLength;

  @override
  State<AppTextInput> createState() => _AppTextInputState();
}

class _AppTextInputState extends State<AppTextInput> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _ownsController = false;
  bool _obscure = true;
  String? _internalError;

  static final _emailRegex = RegExp(r'^\S+@\S+\.\S+$');
  static final _phoneRegex = RegExp(r'^0\d{9}$');

  bool get _isPassword => widget.type == AppTextInputType.password;
  bool get _isMoney => widget.type == AppTextInputType.money;
  bool get _isPhone => widget.type == AppTextInputType.phone;
  bool get _isNumber => widget.type == AppTextInputType.number;
  bool get _isSoLuong => widget.type == AppTextInputType.soLuong;
  bool get _isDigitType => _isMoney || _isPhone || _isNumber || _isSoLuong;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _ownsController = true;
      final initial = widget.initialValue ?? '';
      _controller = TextEditingController(
        text: _isMoney ? _formatMoney(_digitsOnly(initial)) : initial,
      );
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// "1000000" -> "1,000,000" (giống `formatMoney` bên bản React).
  String _formatMoney(String raw) {
    if (raw.isEmpty) return '';
    final reversed = raw.split('').reversed.join();
    final chunks = <String>[];
    for (var i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 > reversed.length) ? reversed.length : i + 3;
      chunks.add(reversed.substring(i, end));
    }
    return chunks.join(',').split('').reversed.join();
  }

  /// Giá trị "thô" hiện tại theo từng loại — dùng để validate & báo ra ngoài.
  String get _rawValue =>
      _isDigitType ? _digitsOnly(_controller.text) : _controller.text.trim();

  /// Xử lý khi rời khỏi ô — tương đương các `onBlur` bên bản React:
  /// - soLuong: trống/<=0 thì về "1".
  /// - money: bỏ số 0 thừa ở đầu.
  void _onFocusChange() {
    if (_focusNode.hasFocus) return;

    if (_isSoLuong) {
      final n = int.tryParse(_controller.text.trim());
      if (_controller.text.trim().isEmpty || n == null || n <= 0) {
        _controller.text = '1';
        widget.onChanged?.call('1');
      }
    } else if (_isMoney) {
      final raw =
          _digitsOnly(_controller.text).replaceFirst(RegExp(r'^0+'), '');
      _controller.text = _formatMoney(raw);
      widget.onChanged?.call(raw);
    }

    setState(() => _internalError = _validate(_rawValue));
  }

  String? _validate(String raw) {
    if (widget.required && raw.isEmpty) {
      return widget.requiredMessage ?? 'Vui lòng nhập thông tin.';
    }
    if (raw.isNotEmpty) {
      switch (widget.type) {
        case AppTextInputType.email:
          if (!_emailRegex.hasMatch(raw)) return 'Email không hợp lệ.';
          break;
        case AppTextInputType.phone:
          if (!_phoneRegex.hasMatch(raw)) {
            return raw.length < 10
                ? 'Số điện thoại phải đủ 10 số.'
                : 'Số điện thoại không hợp lệ.';
          }
          break;
        case AppTextInputType.password:
          if (raw.length < widget.minPasswordLength) {
            return 'Mật khẩu phải có ít nhất ${widget.minPasswordLength} ký tự.';
          }
          if (raw.length > widget.maxPasswordLength) {
            return 'Mật khẩu không được quá ${widget.maxPasswordLength} ký tự.';
          }
          break;
        default:
          break;
      }
    }
    return widget.validator?.call(raw);
  }

  void _handleChanged(String value) {
    if (_isMoney) {
      _handleMoneyChanged(value);
      return;
    }
    widget.onChanged?.call(value);
    // Chỉ tái validate "live" khi đang có lỗi hiển thị, để không báo lỗi
    // ngay lúc người dùng vừa mới gõ ký tự đầu tiên.
    if (_internalError != null) {
      setState(() => _internalError = _validate(_rawValue));
    }
  }

  /// Định dạng lại số tiền + giữ đúng vị trí con trỏ — tương đương
  /// `handleMoneyInput` bên bản React (ở đó phải dùng onInput để né lỗi
  /// IME tiếng Việt; bên Dart, TextField.onChanged đã nhận value sau khi
  /// IME commit nên không cần né thêm).
  void _handleMoneyChanged(String value) {
    final cursor = _controller.selection.end.clamp(0, value.length);
    final raw = _digitsOnly(value);
    final formatted = _formatMoney(raw);

    final digitsBeforeCursor = _digitsOnly(value.substring(0, cursor)).length;
    var newCursor = 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') {
        seen++;
        if (seen == digitsBeforeCursor) {
          newCursor = i + 1;
          break;
        }
        newCursor = i + 1;
      }
    }

    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    widget.onChanged?.call(raw);
    if (_internalError != null) {
      setState(() => _internalError = _validate(raw));
    }
  }

  List<TextInputFormatter>? get _formatters {
    if (_isPhone) {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ];
    }
    if (_isNumber || _isSoLuong) {
      return [FilteringTextInputFormatter.digitsOnly];
    }
    return null;
  }

  TextInputType get _keyboardType {
    switch (widget.type) {
      case AppTextInputType.email:
        return TextInputType.emailAddress;
      case AppTextInputType.phone:
      case AppTextInputType.number:
      case AppTextInputType.soLuong:
      case AppTextInputType.money:
        return TextInputType.number;
      case AppTextInputType.text:
      case AppTextInputType.password:
        return TextInputType.text;
    }
  }

  /// Cho phép truyền `prefixIcon` là `IconData` (gọn, giống `AppTextField`)
  /// hoặc `Widget` bất kỳ (icon tuỳ biến, badge...). Ném lỗi rõ ràng nếu
  /// truyền sai kiểu để dễ phát hiện lúc code thay vì lỗi mờ lúc runtime.
  Widget? _resolvePrefixIcon(BuildContext context, Color color) {
    final icon = widget.prefixIcon;
    if (icon == null) return null;
    if (icon is IconData) return Icon(icon, color: color);
    if (icon is Widget) return icon;
    throw ArgumentError(
      'prefixIcon phải là IconData hoặc Widget, nhận: ${icon.runtimeType}',
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.4}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shownError = widget.errorText ?? _internalError;
    final hasError = shownError != null && shownError.isNotEmpty;

    // Chỉ loại `text` (Họ tên, ghi chú, tìm kiếm...) mới cần gõ tiếng Việt
    // có dấu -> giữ autocorrect/enableSuggestions bật để tránh bug mất chữ.
    final isVietnameseCapable = widget.type == AppTextInputType.text;

    final iconColor = !widget.enabled
        ? scheme.onSurface.withOpacity(0.38)
        : hasError
            ? scheme.error
            : scheme.onSurfaceVariant;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: _isPassword && _obscure,
      keyboardType: _keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: _formatters,
      maxLength: widget.maxLength,
      autocorrect: isVietnameseCapable,
      enableSuggestions: isVietnameseCapable,
      onChanged: _handleChanged,
      onSubmitted: widget.onSubmitted,
      style: theme.textTheme.bodyLarge,
      cursorColor: scheme.primary,
      decoration: InputDecoration(
        labelText: widget.required ? '${widget.label} *' : widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: shownError,
        errorMaxLines: 2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: !widget.enabled
            ? scheme.onSurface.withOpacity(0.04)
            : scheme.surfaceContainerHighest.withOpacity(0.35),
        counterText: widget.maxLength == null ? null : '',
        prefixIcon: _resolvePrefixIcon(context, iconColor),
        suffixIcon: _isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: iconColor,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        border: _border(scheme.outlineVariant),
        enabledBorder: _border(scheme.outlineVariant),
        disabledBorder: _border(scheme.outlineVariant.withOpacity(0.5)),
        focusedBorder: _border(scheme.primary, width: 2),
        errorBorder: _border(scheme.error),
        focusedErrorBorder: _border(scheme.error, width: 2),
      ),
    );
  }
}
