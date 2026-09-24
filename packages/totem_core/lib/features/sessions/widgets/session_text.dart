import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

class SessionTitle extends ConsumerWidget {
  const SessionTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(currentSessionProvider);
    final title = session?.session?.title ?? session?.room?.name;
    if (title == null) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            'SESSION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF787D7E),
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class SessionElapsedTimer extends ConsumerStatefulWidget {
  const SessionElapsedTimer({super.key});

  @override
  ConsumerState<SessionElapsedTimer> createState() =>
      _SessionElapsedTimerState();
}

class _SessionElapsedTimerState extends ConsumerState<SessionElapsedTimer> {
  Timer? _tick;
  DateTime? _start;

  @override
  void initState() {
    super.initState();
    _start = ref.read(featuredTurnStartTimeProvider);
    _syncTimer();
    ref.listenManual(featuredTurnStartTimeProvider, (_, next) {
      setState(() => _start = next);
      _syncTimer();
    });
  }

  @override
  void didUpdateWidget(SessionElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start = ref.read(featuredTurnStartTimeProvider);
    _syncTimer();
  }

  void _syncTimer() {
    _tick?.cancel();
    if (_start != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_start == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final text = _format(DateTime.now().difference(_start!));
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        color: Colors.black54,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

Widget? roundPromptText(String? roundPrompt) {
  if (roundPrompt == null) return null;
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Text(
        '"$roundPrompt"',
        style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      );
    },
  );
}
