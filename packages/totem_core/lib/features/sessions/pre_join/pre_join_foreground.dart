import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/shared/utils.dart';

/// Reports whether new pre-join browser capture may start.
///
/// Flutter Web maps the browser Page Visibility API to its lifecycle states.
/// Keeping this behind an interface lets tests drive visibility without browser
/// channels while native platforms remain eligible for capture.
abstract class PreJoinForegroundMonitor {
  /// Native builds do not gate camera creation on browser tab visibility.
  bool get requiresForegroundGate;

  bool get isForeground;
  Stream<bool> get changes;

  void dispose();
}

class AppLifecyclePreJoinForegroundMonitor
    with WidgetsBindingObserver
    implements PreJoinForegroundMonitor {
  AppLifecyclePreJoinForegroundMonitor.create() {
    _isForeground = !(kIsWeb || kIsWasm) || !isAppHidden();
    if (kIsWeb || kIsWasm) WidgetsBinding.instance.addObserver(this);
  }

  final _changes = StreamController<bool>.broadcast();
  late bool _isForeground;

  @override
  bool get requiresForegroundGate => kIsWeb || kIsWasm;

  @override
  bool get isForeground => _isForeground;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!(kIsWeb || kIsWasm)) return;
    final next = !isAppHidden();
    if (next == _isForeground) return;
    _isForeground = next;
    _changes.add(next);
  }

  @override
  void dispose() {
    if (kIsWeb || kIsWasm) WidgetsBinding.instance.removeObserver(this);
    unawaited(_changes.close());
  }
}

final preJoinForegroundMonitorProvider = Provider<PreJoinForegroundMonitor>((
  ref,
) {
  final monitor = AppLifecyclePreJoinForegroundMonitor.create();
  ref.onDispose(monitor.dispose);
  return monitor;
});
