import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared_main.dart';

void main() {
  sharedMain(TotemWebApp());
}

class TotemWebApp extends StatefulWidget {
  const TotemWebApp({super.key});

  @override
  State<TotemWebApp> createState() => _TotemWebAppState();
}

class _TotemWebAppState extends State<TotemWebApp> {
  final _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          print(state.fullPath);
          return const Scaffold(
            body: Center(
              child: Text('Open a session URL, for example: /my-session'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:sessionSlug',
        builder: (context, state) {
          final slug = state.pathParameters['sessionSlug'] ?? '';
          return PreJoinScreen(sessionSlug: slug);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Page not found'))),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Totem',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
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
