import 'dart:ui';

import 'package:flutter/material.dart';

/// A widget that overlays a blur effect on its child when the app is not in the
/// foreground.
///
/// [SensitiveContent] doesn't work with LiveKit. It causes the UI to go blank.
/// * <https://docs.flutter.dev/platform-integration/android/sensitive-content>
class ProtectionOverlay extends StatefulWidget {
  const ProtectionOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<ProtectionOverlay> createState() => _ProtectionOverlayState();
}

class _ProtectionOverlayState extends State<ProtectionOverlay>
    with WidgetsBindingObserver {
  var _isBlurred = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBlurred = state != AppLifecycleState.resumed;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_isBlurred)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}
