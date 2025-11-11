import 'package:flutter/material.dart';
import 'package:totem_app/core/layout/breakpoints.dart';

/// Provides information about the current layout configuration.
///
/// This class analyzes the screen size and orientation to determine
/// the appropriate device type and layout parameters.
class LayoutInfo {
  const LayoutInfo({
    required this.deviceType,
    required this.screenSize,
    required this.orientation,
    required this.safeAreaPadding,
    required this.breakpoints,
  });

  /// Creates a [LayoutInfo] from the current [BuildContext].
  factory LayoutInfo.fromContext(
    BuildContext context, {
    BreakpointConfig breakpoints = BreakpointConfig.defaultConfig,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final padding = mediaQuery.padding;

    // Calculate orientation from dimensions for more reliable detection
    final orientation = size.width > size.height
        ? Orientation.landscape
        : Orientation.portrait;

    final deviceType = _determineDeviceType(
      size,
      orientation,
      breakpoints,
    );

    return LayoutInfo(
      deviceType: deviceType,
      screenSize: size,
      orientation: orientation,
      safeAreaPadding: padding,
      breakpoints: breakpoints,
    );
  }

  /// The determined device type
  final DeviceType deviceType;

  /// Current screen size
  final Size screenSize;

  /// Current orientation
  final Orientation orientation;

  /// Safe area padding (for notches, status bars, etc.)
  final EdgeInsets safeAreaPadding;

  /// Breakpoint configuration used
  final BreakpointConfig breakpoints;

  /// Determines the device type based on size and orientation.
  static DeviceType _determineDeviceType(
    Size size,
    Orientation orientation,
    BreakpointConfig breakpoints,
  ) {
    final width = size.width;
    final height = size.height;
    final shortestSide = width < height ? width : height;

    // For now, we only handle mobile devices
    // Future implementation will check for tablets, desktop, and web
    if (shortestSide <= breakpoints.mobileMaxWidth) {
      return orientation == Orientation.portrait
          ? DeviceType.mobilePortrait
          : DeviceType.mobileLandscape;
    }

    // Reserved for future implementation
    // When implementing tablet support, add:
    // if (shortestSide <= breakpoints.tabletMaxWidth) {
    //   return orientation == Orientation.portrait
    //       ? DeviceType.tabletPortrait
    //       : DeviceType.tabletLandscape;
    // }

    // Reserved for future implementation
    // When implementing desktop/web support, add platform checks here
    // and return DeviceType.desktop or DeviceType.web

    // Default to mobile for now
    return orientation == Orientation.portrait
        ? DeviceType.mobilePortrait
        : DeviceType.mobileLandscape;
  }

  /// Whether the current device is a mobile phone
  bool get isMobile =>
      deviceType == DeviceType.mobilePortrait ||
      deviceType == DeviceType.mobileLandscape;

  /// Whether the current device is a tablet (reserved for future use)
  bool get isTablet =>
      deviceType == DeviceType.tabletPortrait ||
      deviceType == DeviceType.tabletLandscape;

  /// Whether the current device is desktop (reserved for future use)
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// Whether the current orientation is portrait
  bool get isPortrait =>
      deviceType == DeviceType.mobilePortrait ||
      deviceType == DeviceType.tabletPortrait;

  /// Whether the current orientation is landscape
  bool get isLandscape =>
      deviceType == DeviceType.mobileLandscape ||
      deviceType == DeviceType.tabletLandscape;

  /// Returns appropriate horizontal padding based on device type
  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.mobilePortrait:
        return 16;
      case DeviceType.mobileLandscape:
        return 24;
      case DeviceType.tabletPortrait:
      case DeviceType.tabletLandscape:
        return 32;
      case DeviceType.desktop:
        return 48;
    }
  }

  /// Returns appropriate vertical padding based on device type
  double get verticalPadding {
    switch (deviceType) {
      case DeviceType.mobilePortrait:
        return 16;
      case DeviceType.mobileLandscape:
        return 12;
      case DeviceType.tabletPortrait:
      case DeviceType.tabletLandscape:
        return 24;
      case DeviceType.desktop:
        return 32;
    }
  }

  /// Returns the maximum content width for the current device type
  ///
  /// This is useful for constraining content on larger screens
  double? get maxContentWidth {
    switch (deviceType) {
      case DeviceType.mobilePortrait:
      case DeviceType.mobileLandscape:
        return null; // No constraint on mobile
      case DeviceType.tabletPortrait:
      case DeviceType.tabletLandscape:
        return 768;
      case DeviceType.desktop:
        return 1200;
    }
  }

  /// Returns the number of columns for grid layouts
  int get gridColumns {
    switch (deviceType) {
      case DeviceType.mobilePortrait:
        return 1;
      case DeviceType.mobileLandscape:
        return 2;
      case DeviceType.tabletPortrait:
        return 2;
      case DeviceType.tabletLandscape:
        return 3;
      case DeviceType.desktop:
        return 4;
    }
  }

  /// Returns appropriate spacing for grid layouts
  double get gridSpacing {
    switch (deviceType) {
      case DeviceType.mobilePortrait:
      case DeviceType.mobileLandscape:
        return 16;
      case DeviceType.tabletPortrait:
      case DeviceType.tabletLandscape:
        return 24;
      case DeviceType.desktop:
        return 32;
    }
  }

  @override
  String toString() {
    return 'LayoutInfo('
        'deviceType: $deviceType, '
        'screenSize: $screenSize, '
        'orientation: $orientation'
        ')';
  }
}
