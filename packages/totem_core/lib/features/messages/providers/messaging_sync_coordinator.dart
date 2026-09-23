import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/providers/thread_provider.dart';

/// One foreground-only REST polling coordinator for the messaging feature.
///
/// Firebase only wakes this coordinator; REST remains the source of truth.
final messagingSyncCoordinatorProvider = Provider<MessagingSyncCoordinator>((
  ref,
) {
  final coordinator = MessagingSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
}, name: 'Messaging Sync Coordinator Provider');

class MessagingSyncIntervals {
  const MessagingSyncIntervals._();

  static const inbox = Duration(seconds: 60);
  static const activeThread = Duration(seconds: 15);
  static const quietThread = Duration(seconds: 30);
  static const maxBackoff = Duration(minutes: 5);
}

class MessagingSyncCoordinator with WidgetsBindingObserver {
  MessagingSyncCoordinator(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  final Random _random = Random();
  Timer? _timer;
  bool _isForeground = true;
  bool _inboxVisible = false;
  String? _visibleConversationId;
  int _consecutiveFailures = 0;
  bool _pollInFlight = false;
  DateTime _lastThreadActivity = DateTime.fromMillisecondsSinceEpoch(0);

  void setInboxVisible(bool visible) {
    _inboxVisible = visible;
    _reschedule(immediate: visible);
  }

  void setThreadVisible(String conversationId, bool visible) {
    if (visible) {
      _visibleConversationId = conversationId;
      _lastThreadActivity = DateTime.now();
    } else if (_visibleConversationId == conversationId) {
      _visibleConversationId = null;
    }
    _reschedule(immediate: visible);
  }

  /// Handles both foreground FCM wake-ups and an app resume without trusting
  /// notification payload content as a chat message.
  void wake({String? conversationId}) {
    if (!_isForeground) return;
    if (conversationId != null && conversationId == _visibleConversationId) {
      _lastThreadActivity = DateTime.now();
    }
    // A push updates inbox state even when the Messages tab is not selected.
    unawaited(_poll(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      unawaited(_poll(force: true));
    } else {
      _reschedule();
    }
  }

  Future<void> _poll({bool force = false}) async {
    if (_pollInFlight ||
        !_isForeground ||
        (!force && !_inboxVisible && _visibleConversationId == null)) {
      return;
    }
    _pollInFlight = true;

    try {
      if (_inboxVisible || _visibleConversationId != null) {
        await _ref.read(conversationsProvider.notifier).refresh();
      }
      final conversationId = _visibleConversationId;
      if (conversationId != null) {
        await _ref.read(threadProvider(conversationId).notifier).fetchNewer();
      }
      _consecutiveFailures = 0;
    } catch (_) {
      _consecutiveFailures++;
    } finally {
      _pollInFlight = false;
      _reschedule();
    }
  }

  void _reschedule({bool immediate = false}) {
    _timer?.cancel();
    if (!_isForeground || (!_inboxVisible && _visibleConversationId == null)) {
      return;
    }
    if (immediate) {
      unawaited(_poll());
      return;
    }
    _timer = Timer(_nextInterval(), _poll);
  }

  Duration _nextInterval() {
    final failureMultiplier = 1 << _consecutiveFailures.clamp(0, 4);
    final base = _visibleConversationId == null
        ? MessagingSyncIntervals.inbox
        : DateTime.now().difference(_lastThreadActivity) <
              const Duration(minutes: 2)
        ? MessagingSyncIntervals.activeThread
        : MessagingSyncIntervals.quietThread;
    final milliseconds = min(
      base.inMilliseconds * failureMultiplier,
      MessagingSyncIntervals.maxBackoff.inMilliseconds,
    );
    // ±10% jitter avoids synchronized client polling after an outage.
    final jitter = (_random.nextDouble() * 0.2) - 0.1;
    return Duration(milliseconds: (milliseconds * (1 + jitter)).round());
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
