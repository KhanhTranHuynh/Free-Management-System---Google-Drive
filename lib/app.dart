import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'apis/api_request_manager.dart';
import 'apis/services/auth_api.dart';
import 'components/api_overlay_host.dart';
import 'configs/app_navigator.dart';
import 'configs/app_theme.dart';
import 'routes/app_routes.dart';
import 'stores/auth_store.dart';
import 'stores/theme_store.dart';

/// Widget gốc: MultiProvider, MaterialApp, theme và routes. Không chứa
/// logic nghiệp vụ.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthApi>(create: (_) => AuthApi(ApiRequestManager.instance)),
        ChangeNotifierProvider<AuthStore>(
          create: (context) {
            final store = AuthStore(context.read<AuthApi>());
            // Gắn hàm kiểm tra quyền để ApiRequestManager tự chặn request
            // thiếu quyền ngay tại FE (chỉ tối ưu UX, BE vẫn là nguồn quyết
            // định thật).
            ApiRequestManager.instance.configure(
              permissionChecker: store.coQuyen,
            );
            return store;
          },
        ),
        ChangeNotifierProvider<ThemeStore>(create: (_) => ThemeStore()),
      ],
      child: Consumer<ThemeStore>(
        builder: (context, themeStore, _) {
          return MaterialApp(
            title: 'PhotoFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeStore.mode,
            initialRoute: AppRoutes.login,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            // 👇 MỚI — cần cho AppToast (utils/app_toast.dart): cho phép
            // hiện toast từ những nơi không có BuildContext (vd apis/).
            navigatorKey: appNavigatorKey,
            // Overlay loading toàn app do ApiRequestManager điều khiển.
            builder: (context, child) =>
                ApiOverlayHost(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
