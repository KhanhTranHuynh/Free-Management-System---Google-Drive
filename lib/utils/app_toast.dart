import 'dart:async';

import 'package:flutter/material.dart';

import '../configs/app_colors.dart';
import '../configs/app_navigator.dart';
import '../configs/app_spacing.dart';

/// Loại toast — quyết định màu accent + icon hiển thị.
enum AppToastType { success, error, info }

/// Toast nổi dùng chung toàn app — tương đương react-toastify bên bản
/// React gốc (DEFAULT_TOAST_OPTIONS): tự tắt sau 1 khoảng thời gian, có
/// progress bar đếm ngược, bấm vào để tắt ngay (closeOnClick), vuốt ngang
/// để tắt (thay cho "draggable").
///
/// Không cần BuildContext từ nơi gọi — dùng chung `appNavigatorKey` (xem
/// configs/app_navigator.dart) để lấy Overlay của cả app. Nhờ vậy
/// apis/api_notify.dart (không có BuildContext) vẫn gọi được thẳng
/// AppToast.success()/AppToast.error() sau khi nhận response từ BE.
class AppToast {
  AppToast._();

  /// Thời lượng mặc định trước khi tự tắt — tương đương autoClose: 10000
  /// bên DEFAULT_TOAST_OPTIONS gốc, rút ngắn còn 4s cho phù hợp màn hình
  /// nhỏ (toast để lâu trên mobile dễ che nội dung).
  static const Duration defaultDuration = Duration(seconds: 4);

  static final List<OverlayEntry> _entries = [];

  static void success(String message, {Duration? duration}) =>
      _show(message, AppToastType.success, duration: duration);

  static void error(String message, {Duration? duration}) =>
      _show(message, AppToastType.error, duration: duration);

  static void info(String message, {Duration? duration}) =>
      _show(message, AppToastType.info, duration: duration);

  static void _show(String message, AppToastType type, {Duration? duration}) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      // App chưa render xong (vd gọi quá sớm lúc khởi động) -> bỏ qua
      // thay vì crash, không có toast nào đáng để chặn luồng chính.
      return;
    }

    late final OverlayEntry entry;
    final index = _entries.length;
    entry = OverlayEntry(
      builder: (context) => _ToastCard(
        message: message,
        type: type,
        duration: duration ?? defaultDuration,
        stackIndex: index,
        onDismiss: () {
          if (entry.mounted) entry.remove();
          _entries.remove(entry);
        },
      ),
    );

    _entries.add(entry);
    overlay.insert(entry);
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.type,
    required this.duration,
    required this.stackIndex,
    required this.onDismiss,
  });

  final String message;
  final AppToastType type;
  final Duration duration;
  final int stackIndex;
  final VoidCallback onDismiss;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor => switch (widget.type) {
        AppToastType.success => AppColors.success,
        AppToastType.error => AppColors.error,
        AppToastType.info => AppColors.primary,
      };

  IconData get _icon => switch (widget.type) {
        AppToastType.success => Icons.check_circle,
        AppToastType.error => Icons.error,
        AppToastType.info => Icons.info,
      };

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topSafe + AppSpacing.sm + widget.stackIndex * 64,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => _dismiss(),
        child: GestureDetector(
          // closeOnClick: true
          onTap: _dismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border(
                  left: BorderSide(color: _accentColor, width: 4),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(_icon, color: _accentColor, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _dismiss,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar đếm ngược tới lúc auto tắt.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => LinearProgressIndicator(
                      value: 1 - _controller.value,
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(_accentColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
