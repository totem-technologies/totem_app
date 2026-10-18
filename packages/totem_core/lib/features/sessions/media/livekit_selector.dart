import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Builds from a value [read] from LiveKit objects, reading it again whenever
/// [changes] emits and rebuilding only when it differs by `==`.
///
/// [read] should look objects up fresh, such as a participant by identity,
/// so the widget follows them when they are replaced.
class LiveKitSelector<T> extends StatefulWidget {
  const new({
    required this.changes,
    required this.read,
    required this.builder,
    super.key,
  });

  final Stream<void> changes;
  final T Function() read;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<LiveKitSelector<T>> createState() => _LiveKitSelectorState<T>();
}

class _LiveKitSelectorState<T> extends State<LiveKitSelector<T>> {
  StreamSubscription<void>? _subscription;
  late T _value = widget.read();

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.changes.listen((_) {
      final next = widget.read();
      if (next == _value || !mounted) return;
      setState(() => _value = next);
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LiveKitSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) _listen();
    // Parents pass a fresh lookup on every build.
    _value = widget.read();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
