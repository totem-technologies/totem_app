import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/shared/totem_icons.dart';

class AnimatedPopup extends StatefulWidget {
  const AnimatedPopup({
    required this.onDismissed,
    required this.popup,
    this.animationDuration = const Duration(milliseconds: 400),
    this.duration = const Duration(seconds: 4),
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
            curve: Curves.easeOut,
          ),
        );

    _controller.forward();

    if (widget.duration > Duration.zero) {
      Future.delayed(widget.duration, dismiss);
    }
  }

  Future<void> dismiss() async {
    if (mounted) {
      await _controller.reverse();
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
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

void showPopup(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final key = GlobalKey<AnimatedPopupState>();
  final overlay = Overlay.of(context);

  late OverlayEntry popup;
  popup = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedPopup(
          key: key,
          onDismissed: () {
            if (popup.mounted) {
              popup.remove();
            }
          },
          popup: Builder(builder: builder),
        ),
      ),
    ),
  );

  overlay.insert(popup);
}

void showNotificationPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
}) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    'New message: $message',
    TextDirection.ltr,
  );
  return showPopup(
    context,
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
}) {
  final key = GlobalKey<AnimatedPopupState>();
  final overlay = Overlay.of(context);

  late OverlayEntry popup;
  popup = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedPopup(
          key: key,
          duration: Duration.zero,
          onDismissed: () {
            if (popup.mounted) {
              popup.remove();
            }
          },
          popup: Builder(builder: builder),
        ),
      ),
    ),
  );

  overlay.insert(popup);

  return () {
    key.currentState?.dismiss();
  };
}

VoidCallback showPermanentNotificationPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
}) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    'New message: $message',
    TextDirection.ltr,
  );
  return showDismissiblePopup(
    context,
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
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
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
                spacing: 2,
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
    );
  }
}
