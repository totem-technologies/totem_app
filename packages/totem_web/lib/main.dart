import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared_main.dart';
import 'package:totem_web/auth/controllers/auth_controller.dart';
import 'package:totem_web/core/navigation/redirect/redirect.dart' as redirect;
import 'package:totem_web/core/navigation/web_router.dart';
import 'package:totem_web/core/services/web_api_service.dart';
import 'package:totem_web/firebase_options.dart';

void main() {
  // If the route is not valid, redirect to the main website.
  if (!redirect.ensureValidRoute()) {
    return;
  }

  sharedMain(
    const TotemWebApp(),
    () async {
      TotemRouter.instance = WebTotemRouter();
      usePathUrlStrategy();
    },
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    providerOverrides: [
      authControllerProvider.overrideWith(() => WebAuthController()),
      apiServiceProvider.overrideWith((ref) => ref.read(webApiServiceProvider)),
    ],
  );
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
