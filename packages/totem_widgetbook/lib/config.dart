import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_widgetbook/components.g.dart';
import 'package:widgetbook/widgetbook.dart';

final config = Config(
  components: components,
  // Totem widgets are built on `material_ui`, which has its own Theme and
  // ThemeData types, so Widgetbook's default MaterialApp (built on Flutter's
  // bundled material library) would not theme them.
  appBuilder: (context, child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: Material(child: child),
  ),
  // Render scenarios on a phone-sized viewport. The default (no viewport)
  // gives unbounded constraints, which full-width widgets can't lay out in.
  scenarioConfig: ScenarioConfig(
    definitions: [
      ScenarioDefinition(
        name: 'iPhone 13',
        modes: [ViewportMode(IosViewports.iPhone13)],
      ),
    ],
  ),
  addons: [
    ViewportAddon([
      Viewports.none,
      ...IosViewports.phones,
      ...AndroidViewports.phones,
      ...IosViewports.tablets,
    ]),
    TextScaleAddon(),
    AlignmentAddon(),
    GridAddon(),
    ZoomAddon(),
    SemanticsAddon(),
  ],
);
