import 'package:flutter/material.dart';
import 'package:totem_app/core/layout/breakpoints.dart';
import 'package:totem_app/core/layout/layout_info.dart';

/// A widget that orchestrates how the app is displayed across different
/// devices and orientations.
///
/// This widget provides layout information to its descendants and adapts
/// the UI based on device type (mobile portrait, mobile landscape, tablet,
/// desktop, web).
///
/// Currently supports:
/// - Mobile portrait orientation
/// - Mobile landscape orientation
///
/// Future support (structure in place):
/// - Tablet devices (portrait and landscape)
/// - Desktop devices
/// - Web browsers
///
/// Example usage:
/// ```dart
/// ResponsiveLayoutManager(
///   builder: (context, layoutInfo) {
///     if (layoutInfo.isMobile) {
///       return MobileLayout();
///     } else if (layoutInfo.isTablet) {
///       return TabletLayout();
///     } else {
///       return DesktopLayout();
///     }
///   },
/// )
/// ```
class ResponsiveLayoutManager extends StatelessWidget {
  const ResponsiveLayoutManager({
    required this.builder,
    this.breakpoints = BreakpointConfig.defaultConfig,
    super.key,
  });

  /// Builder function that receives the current [LayoutInfo]
  final Widget Function(BuildContext context, LayoutInfo layoutInfo) builder;

  /// Custom breakpoint configuration (optional)
  final BreakpointConfig breakpoints;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutInfo = LayoutInfo.fromContext(
          context,
          breakpoints: breakpoints,
        );

        return _LayoutInfoProvider(
          layoutInfo: layoutInfo,
          child: Builder(
            builder: (context) => builder(context, layoutInfo),
          ),
        );
      },
    );
  }
}

/// Internal widget that provides [LayoutInfo] to descendants via InheritedWidget.
class _LayoutInfoProvider extends InheritedWidget {
  const _LayoutInfoProvider({
    required this.layoutInfo,
    required super.child,
  });

  final LayoutInfo layoutInfo;

  @override
  bool updateShouldNotify(_LayoutInfoProvider oldWidget) {
    return layoutInfo.deviceType != oldWidget.layoutInfo.deviceType ||
        layoutInfo.screenSize != oldWidget.layoutInfo.screenSize ||
        layoutInfo.orientation != oldWidget.layoutInfo.orientation;
  }

  static LayoutInfo? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_LayoutInfoProvider>()
        ?.layoutInfo;
  }

  static LayoutInfo of(BuildContext context) {
    final layoutInfo = maybeOf(context);
    assert(
      layoutInfo != null,
      'No LayoutInfo found in context. '
      'Make sure ResponsiveLayoutManager is an ancestor of this widget.',
    );
    return layoutInfo!;
  }
}

/// Extension on [BuildContext] to easily access [LayoutInfo].
extension LayoutInfoExtension on BuildContext {
  /// Returns the current [LayoutInfo] from the widget tree.
  ///
  /// Throws an assertion error if no [ResponsiveLayoutManager] is found
  /// in the widget tree.
  LayoutInfo get layoutInfo => _LayoutInfoProvider.of(this);

  /// Returns the current [LayoutInfo] from the widget tree, or null if
  /// no [ResponsiveLayoutManager] is found.
  LayoutInfo? get layoutInfoOrNull => _LayoutInfoProvider.maybeOf(this);
}

/// A widget that adapts its layout based on device type.
///
/// This is a convenience widget that simplifies common layout patterns.
///
/// Example:
/// ```dart
/// AdaptiveLayout(
///   mobilePortrait: MobilePortraitView(),
///   mobileLandscape: MobileLandscapeView(),
///   // Future support
///   tablet: TabletView(),
///   desktop: DesktopView(),
/// )
/// ```
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.mobilePortrait,
    this.mobileLandscape,
    this.tabletPortrait,
    this.tabletLandscape,
    this.desktop,
    this.web,
    super.key,
  });

  /// Widget to display on mobile devices in portrait orientation
  final Widget mobilePortrait;

  /// Widget to display on mobile devices in landscape orientation
  /// If null, falls back to [mobilePortrait]
  final Widget? mobileLandscape;

  /// Widget to display on tablets in portrait orientation (future use)
  /// If null, falls back to [mobilePortrait] or [mobileLandscape]
  final Widget? tabletPortrait;

  /// Widget to display on tablets in landscape orientation (future use)
  /// If null, falls back to [tabletPortrait] or previous fallbacks
  final Widget? tabletLandscape;

  /// Widget to display on desktop devices (future use)
  /// If null, falls back to previous layouts
  final Widget? desktop;

  /// Widget to display on web browsers (future use)
  /// If null, falls back to [desktop] or previous layouts
  final Widget? web;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutManager(
      builder: (context, layoutInfo) {
        switch (layoutInfo.deviceType) {
          case DeviceType.mobilePortrait:
            return mobilePortrait;

          case DeviceType.mobileLandscape:
            return mobileLandscape ?? mobilePortrait;

          case DeviceType.tabletPortrait:
            return tabletPortrait ?? mobileLandscape ?? mobilePortrait;

          case DeviceType.tabletLandscape:
            return tabletLandscape ??
                tabletPortrait ??
                mobileLandscape ??
                mobilePortrait;

          case DeviceType.desktop:
            return desktop ??
                tabletLandscape ??
                tabletPortrait ??
                mobileLandscape ??
                mobilePortrait;

          case DeviceType.web:
            return web ??
                desktop ??
                tabletLandscape ??
                tabletPortrait ??
                mobileLandscape ??
                mobilePortrait;
        }
      },
    );
  }
}

/// A widget that constrains its child to a maximum width based on device type.
///
/// This is useful for preventing content from becoming too wide on large screens.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    required this.child,
    this.maxWidth,
    this.padding,
    super.key,
  });

  /// The widget to constrain
  final Widget child;

  /// Optional custom maximum width (overrides default from LayoutInfo)
  final double? maxWidth;

  /// Optional padding around the child
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final layoutInfo = context.layoutInfo;
    final effectiveMaxWidth = maxWidth ?? layoutInfo.maxContentWidth;

    Widget result = child;

    if (effectiveMaxWidth != null) {
      result = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: result,
        ),
      );
    }

    if (padding != null) {
      result = Padding(padding: padding!, child: result);
    } else {
      // Apply default padding based on device type
      result = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layoutInfo.horizontalPadding,
          vertical: layoutInfo.verticalPadding,
        ),
        child: result,
      );
    }

    return result;
  }
}
