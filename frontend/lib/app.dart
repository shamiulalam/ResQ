import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/theme_notifier.dart';
import 'database/services/chat_notification_service.dart';

class ResQApp extends StatelessWidget {
  const ResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild only this widget when the theme changes — not the entire tree.
    final themeNotifier = context.watch<ThemeNotifier>();

    return MaterialApp(
      navigatorKey: ChatNotificationService.navigatorKey,
      title: 'ResQ',
      debugShowCheckedModeBanner: false,
      // Supply both themes; the active one is controlled by themeMode.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeNotifier.mode == AppThemeMode.light
          ? ThemeMode.light
          : ThemeMode.dark,
      initialRoute: AppRoutes.welcome,
      routes: AppRoutes.routes,
    );
  }
}
