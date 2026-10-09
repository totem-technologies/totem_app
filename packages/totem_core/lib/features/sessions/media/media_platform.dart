import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// Native iOS or Android, where audio routes through the earpiece or the
/// loudspeaker and the camera is chosen by facing rather than by device.
bool get isNativeMobile => lk.lkPlatformIsMobile();

/// Desktop-class devices, including desktop browsers, where users pick
/// cameras and audio outputs from a device list.
bool get usesMediaDevicePicker =>
    kIsWeb ? !lk.lkPlatformIsWebMobile() : lk.lkPlatformIsDesktop();
