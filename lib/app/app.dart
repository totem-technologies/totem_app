import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/controllers/auth_controller.dart';
import '../core/config/theme.dart';
import '../navigation/app_router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // Initialize the router with auth state from Riverpod
    _router = createRouter(ref);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state for navigation
    ref.listen(authControllerProvider, (previous, next) {
      // This will trigger router refresh when auth state changes
      _router.refresh();
    });

    return MaterialApp.router(
      title: 'Totem App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Let system decide theme
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // Add app-wide accessibility features
      builder: (context, child) {
        return MediaQuery(
          // Ensure text scaling respects accessibility settings
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(
              context,
            ).textScaleFactor.clamp(0.8, 1.5),
          ),
          child: child!,
        );
      },
    );
  }
}
