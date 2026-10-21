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
  // The frame has to stay live. A route builder that closes over `child`
  // paints the first story and then ignores the args panel, because the
  // navigator keeps that first page.
  appBuilder: (context, child) => _CatalogFrame(child: child),
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

/// Wraps a story in Totem's theme without freezing it on the first build.
///
/// Widgetbook puts the selected story and its args in the URL query
/// (`/?path=Screens/session/:slug/...&role={value:keeper}`). Flutter web
/// uses that whole string as the initial route. `home:` only matches `/`,
/// so a bare home throws "Could not navigate to initial route".
///
/// `onGenerateRoute` accepts that URL, but the navigator builds the page
/// once and keeps it. The args panel writes the new value into the URL,
/// the story widget above this frame is rebuilt, and the page on screen
/// is still the first one. The slot below is what the page actually
/// reads, so a new child replaces the old one in place.
class _CatalogFrame extends StatefulWidget {
  const _CatalogFrame({required this.child});

  final Widget child;

  @override
  State<_CatalogFrame> createState() => _CatalogFrameState();
}

class _CatalogFrameState extends State<_CatalogFrame> {
  /// Latest story. The route listens to this instead of closing over
  /// the child it was built with.
  final _slot = ValueNotifier<Widget>(const SizedBox.shrink());

  @override
  void initState() {
    super.initState();
    _slot.value = widget.child;
  }

  @override
  void didUpdateWidget(_CatalogFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _slot.value = widget.child;
  }

  @override
  void dispose() {
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        extensions: [
          ...AppTheme.lightTheme.extensions.values,
          TotemTheme.light,
        ],
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ValueListenableBuilder<Widget>(
          valueListenable: _slot,
          builder: (context, child, _) =>
              Material(color: _workbench, child: child),
        ),
      ),
    );
  }
}
