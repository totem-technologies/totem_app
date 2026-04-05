import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/shared/totem_icons.dart';

const _defaultPopupAnimationDuration = Duration(milliseconds: 380);
const _defaultPopupDuration = Duration(milliseconds: 2800);

class AnimatedPopup extends StatefulWidget {
  const AnimatedPopup({
    required this.onDismissed,
    required this.popup,
    this.animationDuration = _defaultPopupAnimationDuration,
    this.duration = _defaultPopupDuration,
    super.key,
  });
  final VoidCallback onDismissed;
  final Widget popup;

  final Duration animationDuration;
  final Duration duration;

  @override
  State<AnimatedPopup> createState() => AnimatedPopupState();
}

class AnimatedPopupState extends State<AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _offsetAnimation =
        Tween<Offset>(
          begin: const Offset(0, -2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _controller.forward();

    if (widget.duration > Duration.zero) {
      _autoDismissTimer = Timer(widget.duration, dismiss);
    }
  }

  Future<void> dismiss() async {
    if (!mounted || _isDismissing) return;

    _isDismissing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.popup,
    );
  }
}

class PopupController {
  final Set<VoidCallback> _activeDismissers = <VoidCallback>{};

  void _register(VoidCallback dismiss) {
    _activeDismissers.add(dismiss);
  }

  void _unregister(VoidCallback dismiss) {
    _activeDismissers.remove(dismiss);
  }

  void dismissAll() {
    final dismissers = List<VoidCallback>.from(_activeDismissers);
    for (final dismiss in dismissers) {
      dismiss();
    }
  }
}

VoidCallback showPopup(
  BuildContext context, {
  required WidgetBuilder builder,
  PopupController? controller,
  Duration animationDuration = _defaultPopupAnimationDuration,
  Duration duration = _defaultPopupDuration,
}) {
  final key = GlobalKey<AnimatedPopupState>();
  final overlay = Overlay.of(context);

  var removed = false;
  late OverlayEntry popup;
  late VoidCallback dismiss;

  void removePopup() {
    if (removed) return;
    removed = true;
    controller?._unregister(dismiss);
    if (popup.mounted) {
      popup.remove();
    }
  }

  popup = OverlayEntry(
    builder: (context) => PositionedDirectional(
      start: 0,
      end: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedPopup(
          key: key,
          animationDuration: animationDuration,
          duration: duration,
          onDismissed: removePopup,
          popup: Builder(builder: builder),
        ),
      ),
    ),
  );

  dismiss = () {
    if (removed) return;

    final state = key.currentState;
    if (state != null) {
      unawaited(state.dismiss());
      return;
    }

    removePopup();
  };

  overlay.insert(popup);

  controller?._register(dismiss);
  return dismiss;
}

void showNotificationPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
  PopupController? controller,
}) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    'New message: $message',
    TextDirection.ltr,
  );
  showPopup(
    context,
    controller: controller,
    builder: (context) {
      return NotificationPopup(
        icon: icon,
        title: title,
        message: message,
      );
    },
  );
}

VoidCallback showDismissiblePopup(
  BuildContext context, {
  required WidgetBuilder builder,
  PopupController? controller,
}) {
  return showPopup(
    context,
    controller: controller,
    duration: Duration.zero,
    builder: builder,
  );
}

VoidCallback showPermanentNotificationPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
  required PopupController controller,
}) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    'New message: $message',
    TextDirection.ltr,
  );
  return showDismissiblePopup(
    context,
    controller: controller,
    builder: (context) {
      return NotificationPopup(
        icon: icon,
        title: title,
        message: message,
      );
    },
  );
}

class NotificationPopup extends StatelessWidget {
  const NotificationPopup({
    required this.icon,
    required this.title,
    required this.message,
    this.iconBackgroundColor,
    super.key,
  });

  final TotemIconData icon;
  final String title;
  final String message;
  final Color? iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 600,
          ),
          margin: const EdgeInsetsDirectional.only(
            top: 20,
            start: 15,
            end: 15,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F1EC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
            boxShadow: kElevationToShadow[2],
          ),
          child: Row(
            spacing: 8,
            children: [
              Container(
                height: 24 + 8,
                width: 24 + 8,
                padding: const EdgeInsetsDirectional.all(8),
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? AppTheme.mauve,
                  shape: BoxShape.circle,
                ),
                child: TotemIcon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      maxLines: 1,
                    ),
                    AutoSizeText(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
