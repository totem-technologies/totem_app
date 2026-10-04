import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_widgetbook/components.g.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

/// Catalog chrome only. Cream screens (`#F3F1E9`) sat on the same
/// beige, so the green viewport frame disappeared. Cool gray keeps
/// the frame readable without touching story backgrounds.
const _workbench = Color(0xFFD8DADF);

final config = Config(
  components: components,
  // Totem widgets are built on `material_ui`, which has its own Theme and
  // ThemeData types, so Widgetbook's default MaterialApp (built on Flutter's
  // bundled material library) would not theme them.
  //
  // TotemTheme.light is catalog-only: Figma copies read it via
  // TotemTheme.of. Production AppTheme in totem_core is unchanged.
  appBuilder: (context, child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme.copyWith(
      extensions: [...AppTheme.lightTheme.extensions.values, TotemTheme.light],
    ),
    // Widgetbook stores the selected story and addons in the URL query
    // (`/?path=Components/Buttons/...`). Flutter web treats that whole
    // string as the initial route name. `home:` only matches `/`, which
    // throws "Could not navigate to initial route". Any URL must still
    // mount the catalog — Widgetbook reads the query itself.
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Material(color: _workbench, child: child),
    ),
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
    // Totem Phone / Tablet / Desktop sit first so they are not buried
    // under the device dump. Then every stock frame: iOS and Android
    // tablets, plus macOS / Windows / Linux for web.
    ViewportAddon([
      TotemViewports.phone,
      TotemViewports.tablet,
      TotemViewports.desktop,
      ...Viewports.all,
    ]),
    TextScaleAddon(),
    AlignmentAddon(),
    GridAddon(),
    ZoomAddon(),
    SemanticsAddon(),
  ],
);
