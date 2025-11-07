/// Defines the device type based on screen size and platform.
enum DeviceType {
  /// Mobile phone in portrait mode
  mobilePortrait,

  /// Mobile phone in landscape mode
  mobileLandscape,

  /// Tablet in portrait mode (reserved for future use)
  tabletPortrait,

  /// Tablet in landscape mode (reserved for future use)
  tabletLandscape,

  /// Desktop device (reserved for future use)
  desktop,

  /// Web browser (reserved for future use)
  web,
}

/// Configuration for responsive breakpoints.
///
/// These breakpoints define when the layout should switch between
/// different device types based on screen dimensions.
class BreakpointConfig {
  const BreakpointConfig({
    this.mobileMaxWidth = 600,
    this.tabletMaxWidth = 1024,
    this.desktopMinWidth = 1025,
  });

  /// Maximum width for mobile devices (in logical pixels)
  final double mobileMaxWidth;

  /// Maximum width for tablet devices (in logical pixels)
  final double tabletMaxWidth;

  /// Minimum width for desktop devices (in logical pixels)
  final double desktopMinWidth;

  /// Default breakpoint configuration
  static const BreakpointConfig defaultConfig = BreakpointConfig();
}
