import 'package:flutter/material.dart';

import '../apis/api_request_manager.dart';

/// Bọc ngoài Navigator (qua `MaterialApp.builder`) để hiện overlay loading
/// toàn app mỗi khi có batch/request bật `showOverlay`. Khi overlay đang
/// hiện, ModalBarrier chặn mọi thao tác chạm bên dưới.
class ApiOverlayHost extends StatelessWidget {
  const ApiOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: ApiRequestManager.instance.overlayVisible,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            return const Positioned.fill(
              child: Stack(
                children: [
                  ModalBarrier(color: Color(0x66000000), dismissible: false),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
