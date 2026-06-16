import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';
import 'package:totem_app/firebase_options.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared_main.dart';

Future<void> main() async {
  try {
    await sharedMain(
      TotemApp(),
      () async {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        TotemRouter.instance = AppTotemRouter();
      },
      providerOverrides: [
        authControllerProvider.overrideWith(MobileAuthController.new),
      ],
    );
  } on ConfigError catch (error, stackTrace) {
    // Broken build, not a runtime issue. Print to stderr and hard-exit so
    // CI smoke tests fail loudly instead of hanging on the native splash.
    stderr
      ..writeln('FATAL: $error')
      ..writeln(stackTrace);
    exit(1);
  }
}

class TotemApp extends ConsumerStatefulWidget {
  const TotemApp({super.key});

  @override
  ConsumerState<TotemApp> createState() => _AppState();
}

class _AppState extends ConsumerState<TotemApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = TotemRouter.instance.createRouter(ref);
    ref.read(notificationsProvider).requestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      final authController = ref.read(mobileAuthControllerProvider);
      if (!authController.isOnboardingCompleted) {
        for (final path in <String>[
          TotemImageAssets.onboarding1,
          TotemImageAssets.onboarding2,
          TotemImageAssets.onboarding3,
        ]) {
          precacheImage(AssetImage(path, package: 'totem_core'), context);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      _router.refresh();
    });

    return MaterialApp.router(
      title: 'Totem',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
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
