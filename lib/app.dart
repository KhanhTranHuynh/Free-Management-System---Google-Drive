import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'apis/auth_api.dart';
import 'configs/app_theme.dart';
import 'configs/env.dart';
import 'routes/app_routes.dart';
import 'stores/auth_store.dart';
import 'stores/theme_store.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()..load()),
        ChangeNotifierProvider(create: (_) => AuthStore(AuthApi())),
      ],
      child: Consumer<ThemeStore>(
        builder: (context, themeStore, _) {
          return MaterialApp(
            title: Env.appName,
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