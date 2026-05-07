import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared_main.dart';
import 'package:totem_web/web_router.dart';

void main() {
  sharedMain(const TotemWebApp(), () async {
    TotemRouter.instance = WebTotemRouter();
  });
}

class TotemWebApp extends ConsumerWidget {
  const TotemWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: TotemRouter.instance.createRouter(ref),
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

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((dynamic _) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
