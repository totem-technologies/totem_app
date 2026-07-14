import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared_main.dart';
import 'package:totem_web/auth/controllers/auth_controller.dart';
import 'package:totem_web/core/navigation/web_router.dart';
import 'package:totem_web/core/services/build_info.dart';
import 'package:totem_web/core/services/web_api_service.dart';

void main() {
  sharedMain(
    const TotemWebApp(),
    () async {
      TotemRouter.instance = WebTotemRouter();
      usePathUrlStrategy();

      _configureVersionInfo();
    },
    providerOverrides: [
      authControllerProvider.overrideWith(() => WebAuthController()),
      apiServiceProvider.overrideWith((ref) => ref.read(webApiServiceProvider)),
    ],
  );
}

void _configureVersionInfo() {
  final buildInfo = BuildInfo.fromEnvironment();
  debugPrint('[Totem] $buildInfo');

  final tags = buildInfo.toSentryTags();
  Sentry.configureScope((scope) {
    for (final entry in tags.entries) {
      scope.setTag(entry.key, entry.value);
    }
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
