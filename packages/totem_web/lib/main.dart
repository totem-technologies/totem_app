import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared_main.dart';

void main() {
  sharedMain(TotemWebApp());
}

class TotemWebApp extends StatelessWidget {
  const TotemWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a web app
    // The url is: https://video.totem.org/{session_slug}
    return MaterialApp.router(
      title: 'Totem',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      // routerConfig: _router,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.5,
          child: child!,
        );
      },
    );
  }
}
