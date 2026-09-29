import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';

const _maxPromptLength = 1000;

Future<void> showSessionPromptsModal(
  BuildContext context, {
  required String sessionSlug,
}) {
  return showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    bottomSheetBackgroundColor: const Color(0xFFF3F1E9),
    dialogBackgroundColor: const Color(0xFFF3F1E9),
    bottomSheetBuilder: (_) => SessionPromptsModal(sessionSlug: sessionSlug),
    largeScreenBuilder: (_) => SizedBox(
      width: 600,
      child: SessionPromptsModal(sessionSlug: sessionSlug),
    ),
  );
}

class SessionPromptsModal extends ConsumerStatefulWidget {
  const SessionPromptsModal({required this.sessionSlug, super.key});

  final String sessionSlug;

  @override
  ConsumerState<SessionPromptsModal> createState() =>
      _SessionPromptsModalState();
}

class _SessionPromptsModalState extends ConsumerState<SessionPromptsModal> {
  List<SessionPromptSchema>? _prompts;
  var _saving = false;

  List<SessionPromptSchema> get _displayed =>
      _prompts!.where((prompt) => prompt.roundNumber.value != null).toList();

  List<SessionPromptSchema> get _future =>
      _prompts!.where((prompt) => prompt.roundNumber.value == null).toList();

  void _adopt(SessionPromptsSchema prompts) {
    if (mounted) setState(() => _prompts = prompts.prompts);
  }

  Future<void> _save(List<SessionPromptSchema> future) async {
    if (_prompts == null || _saving) return;
    setState(() => _saving = true);
    try {
      final result = await ref.read(
        updateSessionPromptsProvider(widget.sessionSlug, [
          ..._displayed,
          ...future,
        ]).future,
      );
      _adopt(result);
    } catch (_) {
      // A prompt may have become displayed while this modal was open. Reload
      // the server's canonical list rather than retaining a stale draft.
      try {
        _adopt(
          await ref.refresh(sessionPromptsProvider(widget.sessionSlug).future),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompts were refreshed because they changed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOrEdit([SessionPromptSchema? prompt]) async {
    final text = await _promptText(context, initialText: prompt?.prompt);
    if (text == null || _prompts == null) return;
    final future = _future;
    if (prompt == null) {
      future.add(SessionPromptSchema(prompt: text));
    } else {
      final index = future.indexOf(prompt);
      if (index < 0) return;
      future[index] = prompt.copyWith(prompt: text);
    }
    await _save(future);
  }

  @override
  Widget build(BuildContext context) {
    final prompts = ref.watch(sessionPromptsProvider(widget.sessionSlug))
      ..whenData((value) {
        if (_prompts == null && !_saving) _prompts = value.prompts;
      });
    final localPrompts = _prompts;
    if (localPrompts == null) {
      return prompts.when(
        loading: () => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(sessionPromptsProvider(widget.sessionSlug)),
            child: const Text('Retry loading prompts'),
          ),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    final displayed = _displayed;
    final future = _future;
    return PopScope(
      canPop: !_saving,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discussion Prompts',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Drag future prompts to set the discussion order.'),
                const SizedBox(height: 16),
                if (displayed.isNotEmpty) ...[
                  const Text('Already discussed'),
                  for (final prompt in displayed)
                    _PromptTile(
                      key: ValueKey('displayed-${prompt.id.value}'),
                      prompt: prompt,
                      locked: true,
                    ),
                  const SizedBox(height: 12),
                ],
                const Text('Future prompts'),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    onReorderItem: _saving
                        ? (_, _) {}
                        : (oldIndex, newIndex) async {
                            final reordered = [...future];
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            await _save(reordered);
                          },
                    children: [
                      for (var index = 0; index < future.length; index++)
                        _PromptTile(
                          key: ValueKey(
                            'future-${future[index].id.value ?? index}',
                          ),
                          prompt: future[index],
                          locked: false,
                          index: index,
                          saving: _saving,
                          onEdit: () => _addOrEdit(future[index]),
                          onDelete: () async {
                            final updated = [...future]..removeAt(index);
                            await _save(updated);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _addOrEdit,
                    icon: const Icon(Icons.add),
                    label: const Text('Add prompt'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.prompt,
    required this.locked,
    super.key,
    this.index,
    this.saving = false,
    this.onEdit,
    this.onDelete,
  });

  final SessionPromptSchema prompt;
  final bool locked;
  final int? index;
  final bool saving;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: locked
            ? const Icon(Icons.lock_outline, semanticLabel: 'Displayed prompt')
            : ReorderableDragStartListener(
                index: index!,
                enabled: !saving,
                child: const Icon(
                  Icons.drag_handle,
                  semanticLabel: 'Drag prompt',
                ),
              ),
        title: Text(prompt.prompt),
        subtitle: locked ? Text('Round ${prompt.roundNumber.value}') : null,
        trailing: locked
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit prompt',
                    onPressed: saving ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete prompt',
                    onPressed: saving ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<String?> _promptText(BuildContext context, {String? initialText}) async {
  final controller = TextEditingController(text: initialText);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialText == null ? 'Add prompt' : 'Edit prompt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: _maxPromptLength,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Discussion prompt'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty || text.length > _maxPromptLength) return;
              Navigator.of(context).pop(text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
