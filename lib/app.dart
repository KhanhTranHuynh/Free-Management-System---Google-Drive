import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'apis/api_client.dart';
import 'apis/auth_api.dart';
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
        Provider<AuthApi>(create: (_) => AuthApi(ApiClient.instance)),
        ChangeNotifierProvider<AuthStore>(
          create: (context) => AuthStore(context.read<AuthApi>()),
        ),
        ChangeNotifierProvider<ThemeStore>(create: (_) => ThemeStore()),
      ],
      child: Consumer<ThemeStore>(
        builder: (context, themeStore, _) {
          return MaterialApp(
            title: 'BMS Client',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeStore.mode,
            initialRoute: AppRoutes.login,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
