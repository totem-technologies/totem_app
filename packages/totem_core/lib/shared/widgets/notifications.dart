import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/utils.dart';

const _defaultNotificationAnimationDuration = Duration(milliseconds: 600);
const _defaultNotificationDuration = Duration(milliseconds: 2800);

class AnimatedNotification extends StatefulWidget {
  const AnimatedNotification({
    required this.onDismissed,
    required this.notification,
    this.animationDuration = _defaultNotificationAnimationDuration,
    this.duration = _defaultNotificationDuration,
    super.key,
  });
  final VoidCallback onDismissed;
  final Widget notification;

  final Duration animationDuration;
  final Duration duration;

  @override
  State<AnimatedNotification> createState() => AnimatedNotificationState();
}

class AnimatedNotificationState extends State<AnimatedNotification>
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
      child: widget.notification,
    );
  }
}

class NotificationRequest {
  NotificationRequest({
    required this.overlay,
    required this.overlayEntry,
    required this.onClosed,
    required this.dedupeKey,
    this.onShown,
  });

  final OverlayState overlay;
  final OverlayEntry overlayEntry;
  final VoidCallback onClosed;
  final Object? dedupeKey;
  final VoidCallback? onShown;

  final GlobalKey<AnimatedNotificationState> key =
      GlobalKey<AnimatedNotificationState>();

  bool _isShown = false;
  bool _isCancelled = false;
  bool _isClosed = false;
  bool _isDismissing = false;

  bool get isCancelled => _isCancelled;

  void show() {
    if (_isShown || _isCancelled) return;

    _isShown = true;
    overlay.insert(overlayEntry);
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

    // An entry inserted while no frames were rendered (e.g. a hidden
    // browser tab) never mounts but still sits in the overlay — remove it
    // whenever it was inserted, not only when it is mounted.
    if (_isShown) {
      overlayEntry.remove();
    }
    close();
  }

  void close() {
    if (_isClosed) return;

    _isClosed = true;
    onClosed();
  }
}

class NotificationController {
  final List<NotificationRequest> _queue = <NotificationRequest>[];
  NotificationRequest? _activeRequest;
  bool _isBulkDismissing = false;
  bool _blocked = false;

  /// When `true`, all active notifications are dismissed and any new
  /// notification requests are silently dropped.
  bool get blocked => _blocked;

  set blocked(bool value) {
    if (_blocked == value) return;
    _blocked = value;
    if (_blocked) {
      dismissAll();
    }
  }

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  bool _hasDuplicate(Object? dedupeKey) {
    if (dedupeKey == null) return false;

    if (_activeRequest?.dedupeKey == dedupeKey) {
      return true;
    }

    return _queue.any((request) => request.dedupeKey == dedupeKey);
  }

  void _enqueue(NotificationRequest request) {
    if (_blocked) {
      request.cancelQueued();
      return;
    }

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

  void _handleRequestClosed(NotificationRequest request) {
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
    final requests = <NotificationRequest>[
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

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Shows an arbitrary widget as a notification banner.
  ///
  /// When this controller is managing the notification, it is queued and
  /// deduplicated by [dedupeKey].
  NotificationRequest show(
    BuildContext context, {
    required WidgetBuilder builder,
    Duration animationDuration = _defaultNotificationAnimationDuration,
    Duration duration = _defaultNotificationDuration,
    VoidCallback? onShown,
    Object? dedupeKey,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    late final NotificationRequest request;

    entry = OverlayEntry(
      builder: (context) => PositionedDirectional(
        start: 0,
        end: 0,
        child: Material(
          color: Colors.transparent,
          child: AnimatedNotification(
            key: request.key,
            animationDuration: animationDuration,
            duration: duration,
            onDismissed: () {
              if (entry.mounted) {
                entry.remove();
              }
              request.close();
            },
            notification: Builder(builder: builder),
          ),
        ),
      ),
    );

    request = NotificationRequest(
      overlay: overlay,
      overlayEntry: entry,
      dedupeKey: dedupeKey,
      onClosed: () {
        _handleRequestClosed(request);
      },
      onShown: onShown,
    );

    // Timed banners that would present while the app is hidden (e.g. a
    // backgrounded browser tab) are stale by the time frames render again,
    // so drop them. Zero-duration banners stay queued so they are still
    // visible when the app returns to the foreground.
    if (duration > Duration.zero && isAppHidden()) {
      request.cancelQueued();
      return request;
    }

    _enqueue(request);

    return request;
  }

  /// Shows a standard notification banner that auto-dismisses after
  /// [_defaultNotificationDuration].
  NotificationRequest showTimed(
    BuildContext context, {
    required TotemIconData icon,
    required String title,
    required String message,
  }) {
    final view = View.of(context);
    return show(
      context,
      dedupeKey: ('notification', icon, title, message),
      onShown: () {
        SemanticsService.sendAnnouncement(
          view,
          'New message: $message',
          TextDirection.ltr,
        );
      },
      builder: (context) {
        return NotificationBanner(
          icon: icon,
          title: title,
          message: message,
        );
      },
    );
  }

  /// Shows a notification banner with custom content that stays until
  /// dismissed manually.
  NotificationRequest showDismissible(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return show(
      context,
      duration: Duration.zero,
      builder: builder,
    );
  }

  /// Shows a notification banner that stays visible until dismissed.
  ///
  /// The notification is deduplicated so that the same
  /// (icon, title, message) combination is only shown once while visible.
  NotificationRequest showPermanent(
    BuildContext context, {
    required TotemIconData icon,
    required String title,
    required String message,
  }) {
    final view = View.of(context);
    return show(
      context,
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
        return NotificationBanner(
          icon: icon,
          title: title,
          message: message,
        );
      },
    );
  }

  /// Shows an error notification banner that auto-dismisses after 5 seconds.
  NotificationRequest showError(
    BuildContext context, {
    required TotemIconData icon,
    required String title,
    required String message,
  }) {
    return show(
      context,
      duration: const Duration(seconds: 5),
      builder: (context) {
        return NotificationBanner(
          icon: icon,
          title: title,
          message: message,
          iconBackgroundColor: const Color(0xFFF44336),
        );
      },
    );
  }
}

class NotificationBanner extends StatelessWidget {
  const NotificationBanner({
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
