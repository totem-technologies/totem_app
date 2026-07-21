import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

class SessionTitle extends ConsumerWidget {
  const SessionTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(currentSessionEventProvider);
    if (session != null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          session.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
