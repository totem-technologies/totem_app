import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';

const _maxPromptLength = 1000;

Future<void> showSessionPromptsModal(
  BuildContext context, {
  required String sessionSlug,
}) {
  return showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    showDragHandle: false,
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

    final currentRound = ref.watch(
      currentSessionStateProvider.select(
        (state) => state?.roomState.roundNumber,
      ),
    );
    final displayed = _displayed;
    final future = _future;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_saving,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetDragHandle(),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 20,
                bottom: 6,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      'Discussion Prompts',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const TotemIcon(
                        TotemIcons.x,
                        size: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 20,
                bottom: 20,
              ),
              child: Text(
                'Drag future prompts to set the discussion order.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 20,
                    ),
                    sliver: SliverList.builder(
                      itemCount: displayed.length,
                      itemBuilder: (context, index) {
                        final prompt = displayed[index];
                        return _PromptTile(
                          key: ValueKey('displayed-${prompt.id.value}'),
                          prompt: prompt,
                          locked: true,
                          current: prompt.roundNumber.value == currentRound,
                        );
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 20,
                    ),
                    sliver: SliverReorderableList(
                      itemCount: future.length,
                      onReorderItem: _saving
                          ? (_, _) {}
                          : (oldIndex, newIndex) async {
                              final reordered = [...future];
                              final item = reordered.removeAt(oldIndex);
                              reordered.insert(newIndex, item);
                              await _save(reordered);
                            },
                      itemBuilder: (context, index) => _PromptTile(
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
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(40, 20, 40, 12),
              child: ElevatedButton(
                onPressed: _saving ? null : _addOrEdit,
                child: const Text('Add prompt'),
              ),
            ),
          ],
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
    this.current = false,
    this.index,
    this.saving = false,
    this.onEdit,
    this.onDelete,
  });

  final SessionPromptSchema prompt;
  final bool locked;
  final bool current;
  final int? index;
  final bool saving;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const foreground = Colors.black;
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: current ? AppTheme.mauve.withValues(alpha: 0.16) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: current ? Border.all(color: AppTheme.mauve) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 10),
            child: locked
                ? const TotemIcon(
                    TotemIcons.lock,
                    size: 18,
                    color: Colors.black,
                  )
                : ReorderableDragStartListener(
                    index: index!,
                    enabled: !saving,
                    child: const TotemIcon(
                      TotemIcons.reorderParticipants,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current)
                  Text(
                    'Current prompt',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.mauve,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  prompt.prompt,
                  style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
                ),
                if (locked && !current)
                  Text(
                    'Round ${prompt.roundNumber.value}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
          if (!locked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit prompt',
                  onPressed: saving ? null : onEdit,
                  icon: const TotemIcon(
                    TotemIcons.edit,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete prompt',
                  onPressed: saving ? null : onDelete,
                  icon: const TotemIcon(
                    TotemIcons.delete,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<String?> _promptText(BuildContext context, {String? initialText}) async {
  final controller = TextEditingController(text: initialText);
  final formKey = GlobalKey<FormState>();
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: initialText == null ? 'Add prompt' : 'Edit prompt',
        content: 'Enter a discussion prompt for this Session.',
        confirmButtonText: 'Save',
        type: ConfirmationDialogType.standard,
        contentWidget: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: _maxPromptLength,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Discussion prompt'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a prompt';
              }
              if (value.trim().length > _maxPromptLength) {
                return 'Prompts can be at most $_maxPromptLength characters';
              }
              return null;
            },
          ),
        ),
        onConfirm: () async {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(context).pop(controller.text.trim());
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}
