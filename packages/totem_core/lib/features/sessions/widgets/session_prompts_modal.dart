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
  var _nextDraftId = -1;

  List<SessionPromptSchema> get _displayed =>
      _prompts!.where((prompt) => prompt.consumedRoundNumber != null).toList();

  List<SessionPromptSchema> get _future =>
      _prompts!.where((prompt) => prompt.consumedRoundNumber == null).toList();

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
      future.add(
        SessionPromptSchema(
          id: _nextDraftId--,
          prompt: text,
          position: null,
          consumedRoundNumber: null,
        ),
      );
    } else {
      final index = future.indexOf(prompt);
      if (index < 0) return;
      future[index] = prompt.copyWith(prompt: text);
    }
    await _save(future);
  }

  Future<void> _setCurrentPrompt({
    String? customPrompt,
    int? sessionPromptId,
  }) async {
    final session = ref.read(currentSessionProvider);
    if (session == null || _saving) return;
    setState(() => _saving = true);
    try {
      await session.keeper.setPrompt(
        customPrompt: customPrompt,
        sessionPromptId: sessionPromptId,
      );
      _adopt(
        await ref.refresh(sessionPromptsProvider(widget.sessionSlug).future),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final currentRoundPrompt = ref.watch(currentSessionPromptProvider);
    final displayed = _displayed;
    final hasCurrentPreparedPrompt = displayed.any(
      (prompt) => prompt.consumedRoundNumber == currentRound,
    );
    final showCustomCurrentPrompt =
        currentRoundPrompt != null && !hasCurrentPreparedPrompt;
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
                  if (_saving || prompts.isLoading)
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          ),
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
                      itemCount:
                          displayed.length + (showCustomCurrentPrompt ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showCustomCurrentPrompt &&
                            index == displayed.length) {
                          return _PromptTile(
                            key: ValueKey('custom-current-$currentRound'),
                            prompt: SessionPromptSchema(
                              id: 0,
                              prompt: currentRoundPrompt,
                              position: null,
                              consumedRoundNumber: currentRound,
                            ),
                            locked: true,
                            current: true,
                            onEdit: () async {
                              final text = await _promptText(
                                context,
                                initialText: currentRoundPrompt,
                              );
                              if (text != null) {
                                await _setCurrentPrompt(customPrompt: text);
                              }
                            },
                          );
                        }

                        final prompt = displayed[index];
                        return _PromptTile(
                          key: ValueKey('displayed-${prompt.id}'),
                          prompt: prompt,
                          locked: true,
                          current: prompt.consumedRoundNumber == currentRound,
                          onEdit: prompt.consumedRoundNumber == currentRound
                              ? () async {
                                  final text = await _promptText(
                                    context,
                                    initialText: prompt.prompt,
                                  );
                                  if (text != null) {
                                    await _setCurrentPrompt(customPrompt: text);
                                  }
                                }
                              : null,
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
                        key: ValueKey('future-${future[index].id}'),
                        prompt: future[index],
                        locked: false,
                        index: index,
                        saving: _saving,
                        onEdit: () => _addOrEdit(future[index]),
                        onSelect: currentRound == null
                            ? null
                            : () => _setCurrentPrompt(
                                sessionPromptId: future[index].id,
                              ),
                        onDelete: () async {
                          final shouldDelete = await _confirmPromptDeletion(
                            context,
                          );
                          if (shouldDelete != true) return;
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
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _saving ? null : _addOrEdit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Add Prompt'),
                ),
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
    this.onSelect,
  });

  final SessionPromptSchema prompt;
  final bool locked;
  final bool current;
  final int? index;
  final bool saving;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const foreground = Colors.black;
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: current ? AppTheme.mauve.withValues(alpha: 0.16) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: current ? Border.all(color: AppTheme.mauve) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: locked
                  ? const TotemIcon(
                      TotemIcons.lock,
                      size: 18,
                      color: Colors.black,
                    )
                  : ReorderableDragStartListener(
                      index: index!,
                      enabled: !saving,
                      child: const SizedBox.square(
                        dimension: 40,
                        child: Center(
                          child: TotemIcon(
                            TotemIcons.reorderParticipants,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
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
                SelectableText(
                  prompt.prompt,
                  style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
                ),
                if (locked && !current)
                  Text(
                    'Round ${prompt.consumedRoundNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
          if (!locked || onEdit != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                if (onSelect != null)
                  ElevatedButton(
                    onPressed: saving ? null : onSelect,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10,
                      ),
                      textStyle: theme.textTheme.labelSmall,
                    ),
                    child: const Text('Use now'),
                  ),

                if (onEdit != null)
                  IconButton(
                    tooltip: current ? 'Edit current prompt' : 'Edit prompt',
                    onPressed: saving ? null : onEdit,
                    icon: const TotemIcon(
                      TotemIcons.edit,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                if (!locked)
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

Future<bool?> _confirmPromptDeletion(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ConfirmationDialog(
      title: 'Delete Prompt?',
      content: 'Are you sure you want to delete this prompt?',
      confirmButtonText: 'Delete',
      type: ConfirmationDialogType.destructive,
      onConfirm: () async => Navigator.of(context).pop(true),
    ),
  );
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
            style: const TextStyle(color: AppTheme.slate),
            cursorColor: AppTheme.mauve,
            decoration: InputDecoration(
              hintText: 'Discussion prompt',
              hintStyle: const TextStyle(color: AppTheme.gray),
              filled: true,
              fillColor: Colors.white,
              counterStyle: const TextStyle(color: AppTheme.gray),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.gray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.mauve),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.errorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.errorColor),
              ),
            ),
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
