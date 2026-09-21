import 'package:flutter/material.dart';

/// Navigator key dùng CHUNG cho toàn app.
///
/// Mục đích: cho phép các lớp không có BuildContext (vd AppToast trong
/// utils/, hoặc sau này là 1 API interceptor nào đó) vẫn truy cập được
/// Overlay/Navigator để hiển thị toast/dialog toàn cục, mà không cần
/// truyền context xuyên suốt apis/ -> stores/ -> views/ (vi phạm chiều
/// phụ thuộc: apis/ và stores/ không được cầm BuildContext).
///
/// Gắn vào MaterialApp(navigatorKey: appNavigatorKey, ...) trong app.dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
