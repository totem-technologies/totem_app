import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            'SPACE',
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

Widget? roundPromptText(String? roundPrompt) {
  if (roundPrompt == null) return null;
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Text(
        '"$roundPrompt"',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      );
    },
  );
}
