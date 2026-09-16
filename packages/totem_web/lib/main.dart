import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared_main.dart';
import 'package:totem_web/auth/controllers/auth_controller.dart';
import 'package:totem_web/core/navigation/web_router.dart';
import 'package:totem_web/core/services/web_api_service.dart';
import 'package:web/web.dart' as web;

void main() {
  RoomBackground.onBackgroundChanged = (color) {
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    web.document.body?.style.setProperty('background-color', hex);
  };

  sharedMain(
    const TotemWebApp(),
    () async {
      TotemRouter.instance = WebTotemRouter();
      usePathUrlStrategy();
    },
    providerOverrides: [
      authControllerProvider.overrideWith(() => WebAuthController()),
      apiServiceProvider.overrideWith((ref) => ref.read(webApiServiceProvider)),
    ],
  );
}

class TotemWebApp extends ConsumerStatefulWidget {
  const TotemWebApp({super.key});

  @override
  ConsumerState<TotemWebApp> createState() => _TotemWebAppState();
}

class _TotemWebAppState extends ConsumerState<TotemWebApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = TotemRouter.instance.createRouter(ref);
  }

  @override
  void dispose() {
    TotemRouter.instance.dispose();
    _router.dispose();
    super.dispose();
  }

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
