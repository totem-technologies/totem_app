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

/// Mirrors the room background onto the page body so any area the Flutter
/// view doesn't cover (e.g. when mobile browser chrome resizes the viewport)
/// matches the session instead of showing the default white page.
///
/// Flutter web sizes `body` with `position: fixed; inset: 0`, so the body's
/// box is empty for background painting. A CSS gradient without
/// `background-attachment: fixed` can collapse to nothing and leave only
/// `background-color` showing — mauve at the top of the waiting room. Pin
/// the gradient to the viewport so cream stays at the top and mauve/slate
/// cover the bottom strip.
void _applyPageBackground(BoxDecoration decoration) {
  final style = web.document.body?.style;
  if (style == null) return;

  String toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  final gradient = decoration.gradient;
  if (gradient is LinearGradient) {
    final colors = gradient.colors;
    final stops =
        gradient.stops ??
        List<double>.generate(
          colors.length,
          (index) => index / (colors.length - 1),
        );
    final value = StringBuffer('linear-gradient(to bottom');
    for (var index = 0; index < colors.length; index++) {
      value
        ..write(', ')
        ..write(toHex(colors[index]))
        ..write(' ')
        ..write('${stops[index] * 100}%');
    }
    value.write(')');
    // Viewport-sized gradient; [colors.last] fills anything the image
    // doesn't cover (the original white bottom bar).
    style
      ..setProperty('background-color', toHex(colors.last))
      ..setProperty('background-image', value.toString())
      ..setProperty('background-repeat', 'no-repeat')
      ..setProperty('background-attachment', 'fixed');
  } else if (decoration.color != null) {
    // Solid fill (in-session slate, or cream once the room unmounts).
    // Drop gradient leftovers so they can't peek through on the next route.
    style
      ..setProperty('background-image', 'none')
      ..removeProperty('background-repeat')
      ..removeProperty('background-attachment')
      ..setProperty('background-color', toHex(decoration.color!));
  }
}

Future<void> main() async {
  RoomBackground.onBackgroundChanged = _applyPageBackground;

  await sharedMain(
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
