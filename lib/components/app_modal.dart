import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Kiểu hiển thị của modal trên mobile.
enum AppModalType {
  /// Trượt từ dưới lên - phổ biến nhất cho form thêm/sửa trên mobile.
  bottomSheet,

  /// Popup giữa màn hình - dùng cho xác nhận / form ngắn.
  dialog,

  /// Toàn màn hình - dùng cho form dài.
  fullScreen,
}

Future<T?> showAppModal<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? subTitle,
  WidgetBuilder? footerBuilder,
  AppModalType type = AppModalType.bottomSheet,
  bool closeOnBackdropClick = false,
  bool hideClose = false,
  bool showDivider = true,
  Color? background,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false, // tự xử lý backdrop để có hiệu ứng rung
    barrierLabel: title,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 250),
    // Animation do panel tự xử lý (để vùng backdrop không bị trượt theo)
    transitionBuilder: (_, __, ___, child) => child,
    pageBuilder: (ctx, animation, _) => _AppModalHost(
      animation: animation,
      title: title,
      subTitle: subTitle,
      builder: builder,
      footerBuilder: footerBuilder,
      type: type,
      closeOnBackdropClick: closeOnBackdropClick,
      hideClose: hideClose,
      showDivider: showDivider,
      background: background,
    ),
  );
}

class _AppModalHost extends StatefulWidget {
  final Animation<double> animation;
  final String title;
  final String? subTitle;
  final WidgetBuilder builder;
  final WidgetBuilder? footerBuilder;
  final AppModalType type;
  final bool closeOnBackdropClick;
  final bool hideClose;
  final bool showDivider;
  final Color? background;

  const _AppModalHost({
    required this.animation,
    required this.title,
    required this.builder,
    required this.type,
    required this.closeOnBackdropClick,
    required this.hideClose,
    required this.showDivider,
    this.subTitle,
    this.footerBuilder,
    this.background,
  });

  @override
  State<_AppModalHost> createState() => _AppModalHostState();
}

class _AppModalHostState extends State<_AppModalHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _curved.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _triggerShake() => _shake.forward(from: 0);

  void _onBackdropTap() {
    FocusScope.of(context).unfocus();
    if (widget.closeOnBackdropClick) {
      Navigator.of(context).maybePop();
    } else {
      _triggerShake();
    }
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: widget.showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (widget.subTitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.subTitle!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.hideClose)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final theme = Theme.of(context);
    final isFull = widget.type == AppModalType.fullScreen;

    final radius = switch (widget.type) {
      AppModalType.bottomSheet =>
        const BorderRadius.vertical(top: Radius.circular(20)),
      AppModalType.dialog => BorderRadius.circular(16),
      AppModalType.fullScreen => BorderRadius.zero,
    };

    return Material(
      color: widget.background ?? theme.colorScheme.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: SafeArea(
        top: isFull,
        bottom: widget.type != AppModalType.dialog,
        child: Column(
          mainAxisSize: isFull ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh kéo nhỏ cho bottom sheet
            if (widget.type == AppModalType.bottomSheet)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            _header(context),
            Flexible(
              fit: isFull ? FlexFit.tight : FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: widget.builder(context),
              ),
            ),
            if (widget.footerBuilder != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: widget.showDivider
                    ? BoxDecoration(
                        border: Border(
                          top: BorderSide(color: theme.dividerColor),
                        ),
                      )
                    : null,
                child: widget.footerBuilder!(context),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final availableH = mq.size.height - keyboard;

    Widget panel = _panel(context);

    // Rung khi không cho đóng
    panel = AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          math.sin(_shake.value * math.pi * 6) * 8 * (1 - _shake.value),
          0,
        ),
        child: child,
      ),
      child: panel,
    );

    final Widget positioned;
    switch (widget.type) {
      case AppModalType.bottomSheet:
        positioned = Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (availableH - mq.padding.top) * 0.92,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_curved),
                child: panel,
              ),
            ),
          ),
        );
        break;

      case AppModalType.dialog:
        positioned = Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboard),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: availableH * 0.85,
              ),
              child: FadeTransition(
                opacity: _curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(_curved),
                  child: panel,
                ),
              ),
            ),
          ),
        );
        break;

      case AppModalType.fullScreen:
        positioned = Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox.expand(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_curved),
              child: panel,
            ),
          ),
        );
        break;
    }

    return PopScope(
      canPop: widget.closeOnBackdropClick,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _triggerShake(); // bấm Back mà không cho đóng -> rung
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onBackdropTap,
            ),
          ),
          positioned,
        ],
      ),
    );
  }
}
