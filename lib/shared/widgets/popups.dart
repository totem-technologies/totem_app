import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/shared/totem_icons.dart';

const _defaultPopupAnimationDuration = Duration(milliseconds: 600);
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

class PopupRequest {
  PopupRequest({
    required this.overlay,
    required this.popup,
    required this.onClosed,
    required this.dedupeKey,
    this.onShown,
  });

  final OverlayState overlay;
  final OverlayEntry popup;
  final VoidCallback onClosed;
  final Object? dedupeKey;
  final VoidCallback? onShown;

  final GlobalKey<AnimatedPopupState> key = GlobalKey<AnimatedPopupState>();

  bool _isShown = false;
  bool _isCancelled = false;
  bool _isClosed = false;
  bool _isDismissing = false;

  bool get isCancelled => _isCancelled;

  void show() {
    if (_isShown || _isCancelled) return;

    _isShown = true;
    overlay.insert(popup);
    onShown?.call();
  }

  void cancelQueued() {
    if (_isShown || _isCancelled || _isClosed) return;

    _isCancelled = true;
  }

  void dismissActive() {
    if (_isClosed || _isDismissing) return;

    _isDismissing = true;

    final state = key.currentState;
    if (state != null) {
      unawaited(state.dismiss());
      return;
    }

    if (popup.mounted) {
      popup.remove();
    }
    close();
  }

  void close() {
    if (_isClosed) return;

    _isClosed = true;
    onClosed();
  }
}

class PopupController {
  final List<PopupRequest> _queue = <PopupRequest>[];
  PopupRequest? _activeRequest;
  bool _isBulkDismissing = false;

  bool _hasDuplicate(Object? dedupeKey) {
    if (dedupeKey == null) return false;

    if (_activeRequest?.dedupeKey == dedupeKey) {
      return true;
    }

    return _queue.any((request) => request.dedupeKey == dedupeKey);
  }

  void _enqueue(PopupRequest request) {
    if (_hasDuplicate(request.dedupeKey)) {
      return;
    }

    _queue.add(request);
    _pumpQueue();
  }

  void _pumpQueue() {
    if (_activeRequest != null) return;

    while (_queue.isNotEmpty) {
      final nextRequest = _queue.removeAt(0);
      if (nextRequest.isCancelled) {
        continue;
      }

      _activeRequest = nextRequest;
      nextRequest.show();
      break;
    }
  }

  void _handleRequestClosed(PopupRequest request) {
    if (_activeRequest == request) {
      _activeRequest = null;
    } else {
      _queue.remove(request);
    }

    if (!_isBulkDismissing) {
      _pumpQueue();
    }
  }

  void dismissAll() {
    final requests = <PopupRequest>[
      ..._queue,
      ?_activeRequest,
    ];

    if (requests.isEmpty) return;

    _isBulkDismissing = true;
    for (final request in requests) {
      if (request == _activeRequest) {
        request.dismissActive();
      } else {
        request.cancelQueued();
      }
    }
    _queue.clear();
    _activeRequest = null;
    _isBulkDismissing = false;
  }
}

PopupRequest showPopup(
  BuildContext context, {
  required WidgetBuilder builder,
  PopupController? controller,
  Duration animationDuration = _defaultPopupAnimationDuration,
  Duration duration = _defaultPopupDuration,
  VoidCallback? onShown,
  Object? dedupeKey,
}) {
  final overlay = Overlay.of(context);

  late OverlayEntry popup;
  late final PopupRequest request;

  popup = OverlayEntry(
    builder: (context) => PositionedDirectional(
      start: 0,
      end: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedPopup(
          key: request.key,
          animationDuration: animationDuration,
          duration: duration,
          onDismissed: () {
            if (popup.mounted) {
              popup.remove();
            }
            request.close();
          },
          popup: Builder(builder: builder),
        ),
      ),
    ),
  );

  request = PopupRequest(
    overlay: overlay,
    popup: popup,
    dedupeKey: dedupeKey,
    onClosed: () {
      controller?._handleRequestClosed(request);
    },
    onShown: onShown,
  );

  if (controller != null) {
    controller._enqueue(request);
  } else {
    request.show();
  }

  return request;
}

void showNotificationPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
  PopupController? controller,
}) {
  final view = View.of(context);
  showPopup(
    context,
    controller: controller,
    dedupeKey: ('notification', icon, title, message),
    onShown: () {
      SemanticsService.sendAnnouncement(
        view,
        'New message: $message',
        TextDirection.ltr,
      );
    },
    builder: (context) {
      return NotificationPopup(
        icon: icon,
        title: title,
        message: message,
      );
    },
  );
}

PopupRequest showDismissiblePopup(
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

PopupRequest showPermanentNotificationPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
  required PopupController controller,
}) {
  final view = View.of(context);
  return showPopup(
    context,
    controller: controller,
    duration: Duration.zero,
    dedupeKey: ('permanent_notification', icon, title, message),
    onShown: () {
      SemanticsService.sendAnnouncement(
        view,
        'New message: $message',
        TextDirection.ltr,
      );
    },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 600;

          return Align(
            alignment: isLargeScreen
                ? AlignmentDirectional.topStart
                : Alignment.center,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 400 : 600,
              ),
              margin: EdgeInsetsDirectional.only(
                top: 20,
                start: 15,
                end: isLargeScreen ? 0 : 15,
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
          );
        },
      ),
    );
  }
}
