import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';

const _maxPromptLength = 1000;

Future<void> showSessionPromptsModal(
  BuildContext context, {
  required String sessionSlug,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (shouldDockSessionSidePanel(context) &&
      container.read(currentSessionProvider) != null) {
    container.read(sessionPromptsOpenProvider.notifier).open = true;
    container.read(sessionChatOpenProvider.notifier).open = false;
    return Future.value();
  }

  return showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    showDragHandle: false,
    bottomSheetBackgroundColor: AppTheme.cream,
    dialogBackgroundColor: AppTheme.cream,
    bottomSheetBuilder: (_) => SessionPromptsModal(sessionSlug: sessionSlug),
    largeScreenBuilder: (_) => SizedBox(
      width: 600,
      child: SessionPromptsModal(sessionSlug: sessionSlug),
    ),
  );
}

class SessionPromptsModal extends ConsumerStatefulWidget {
  const SessionPromptsModal({
    required this.sessionSlug,
    this.embedded = false,
    super.key,
  });

  final String sessionSlug;
  final bool embedded;

  @override
  ConsumerState<SessionPromptsModal> createState() =>
      _SessionPromptsModalState();
}

class _SessionPromptsModalState extends ConsumerState<SessionPromptsModal> {
  List<SessionPromptSchema>? _prompts;
  final Map<int, GlobalKey> _promptKeys = {};
  var _saving = false;
  var _nextDraftId = -1;

  void _adopt(SessionPromptsSchema prompts) {
    if (mounted) setState(() => _prompts = prompts.prompts);
  }

  Future<void> _save(
    List<SessionPromptSchema> prompts, {
    int? revealIndex,
  }) async {
    if (_prompts == null || _saving) return;
    setState(() {
      _prompts = prompts;
      _saving = true;
    });
    try {
      final result = await ref.read(
        updateSessionPromptsProvider(widget.sessionSlug, prompts).future,
      );
      _adopt(result);
      if (revealIndex case final index?) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && index < result.prompts.length) {
          final prompt = result.prompts[index];
          final targetContext = _promptKey(prompt.id).currentContext;
          if (targetContext != null && targetContext.mounted) {
            await Scrollable.ensureVisible(
              targetContext,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }
      }
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
    final prompts = [..._prompts!];
    final revealIndex = prompt == null ? prompts.length : null;
    if (prompt == null) {
      prompts.add(
        SessionPromptSchema(
          id: _nextDraftId--,
          prompt: text,
          position: null,
          consumedRoundNumbers: const [],
        ),
      );
    } else {
      final index = prompts.indexOf(prompt);
      if (index < 0) return;
      prompts[index] = prompt.copyWith(prompt: text);
    }
    await _save(prompts, revealIndex: revealIndex);
  }

  GlobalKey _promptKey(int id) => _promptKeys.putIfAbsent(id, GlobalKey.new);

  void _closePanel() {
    if (widget.embedded) {
      ref.read(sessionPromptsOpenProvider.notifier).open = false;
      return;
    }
    Navigator.of(context).maybePop();
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
    final hasCurrentPreparedPrompt = localPrompts.any(
      (prompt) => prompt.consumedRoundNumbers.contains(currentRound),
    );
    final showCustomCurrentPrompt =
        currentRoundPrompt != null && !hasCurrentPreparedPrompt;
    final theme = Theme.of(context);
    final horizontalPadding = widget.embedded ? 16.0 : 20.0;

    return PopScope(
      canPop: !_saving,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              if (!widget.embedded) const SheetDragHandle(),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  horizontalPadding,
                  widget.embedded ? 12 : 0,
                  horizontalPadding,
                  12,
                ),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: Center(
                        child: _saving || prompts.isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Discussion Prompts',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Drag prompts to set the discussion order.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        onPressed: _saving ? null : _closePanel,
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
              Flexible(
                child: CustomScrollView(
                  slivers: [
                    if (showCustomCurrentPrompt)
                      SliverPadding(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _PromptTile(
                            key: ValueKey('custom-current-$currentRound'),
                            prompt: SessionPromptSchema(
                              id: 0,
                              prompt: currentRoundPrompt,
                              position: null,
                              consumedRoundNumbers: currentRound == null
                                  ? const []
                                  : [currentRound],
                            ),
                            current: true,
                            panelLayout: widget.embedded,
                            onEdit: () async {
                              final text = await _promptText(
                                context,
                                initialText: currentRoundPrompt,
                              );
                              if (text != null) {
                                await _setCurrentPrompt(customPrompt: text);
                              }
                            },
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverReorderableList(
                        itemCount: localPrompts.length,
                        onReorderItem: _saving
                            ? (_, _) {}
                            : (oldIndex, newIndex) async {
                                final reordered = [...localPrompts];
                                final item = reordered.removeAt(oldIndex);
                                reordered.insert(newIndex, item);
                                await _save(reordered);
                              },
                        itemBuilder: (context, index) {
                          final prompt = localPrompts[index];
                          final current = prompt.consumedRoundNumbers.contains(
                            currentRound,
                          );
                          return _PromptTile(
                            key: _promptKey(prompt.id),
                            prompt: prompt,
                            current: current,
                            panelLayout: widget.embedded,
                            index: index,
                            saving: _saving,
                            onEdit: current
                                ? () async {
                                    final text = await _promptText(
                                      context,
                                      initialText: prompt.prompt,
                                    );
                                    if (text != null) {
                                      await _setCurrentPrompt(
                                        customPrompt: text,
                                      );
                                    }
                                  }
                                : () => _addOrEdit(prompt),
                            onSelect: currentRound == null || current
                                ? null
                                : () => _setCurrentPrompt(
                                    sessionPromptId: prompt.id,
                                  ),
                            onDelete: () async {
                              final shouldDelete = await _confirmPromptDeletion(
                                context,
                              );
                              if (shouldDelete != true) return;
                              final updated = [...localPrompts]
                                ..removeAt(index);
                              await _save(updated);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  widget.embedded ? 20 : 40,
                  16,
                  widget.embedded ? 20 : 40,
                  16,
                ),
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
      ),
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.prompt,
    super.key,
    this.current = false,
    this.panelLayout = false,
    this.index,
    this.saving = false,
    this.onEdit,
    this.onDelete,
    this.onSelect,
  });

  final SessionPromptSchema prompt;
  final bool current;
  final bool panelLayout;
  final int? index;
  final bool saving;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const foreground = Colors.black;
    final dragHandle = SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: index == null
            ? const TotemIcon(TotemIcons.history, size: 18, color: Colors.black)
            : Tooltip(
                message: 'Drag to reorder prompts',
                child: ReorderableDragStartListener(
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
    );
    final promptText = Expanded(
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
          if (!current && prompt.consumedRoundNumbers.isNotEmpty)
            Text(
              'Used in rounds ${prompt.consumedRoundNumbers.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.mauve),
            ),
        ],
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (onSelect != null)
          if (prompt.consumedRoundNumbers.isNotEmpty)
            OutlinedButton(
              onPressed: saving ? null : onSelect,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
                textStyle: theme.textTheme.labelSmall,
              ),
              child: const Text('Use now'),
            )
          else
            ElevatedButton(
              onPressed: saving ? null : onSelect,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
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
        if (onDelete != null)
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
    );
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: current
            ? AppTheme.mauve.withValues(alpha: 0.16)
            : prompt.consumedRoundNumbers.isNotEmpty
            ? AppTheme.mauve.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: current
            ? Border.all(color: AppTheme.mauve)
            : prompt.consumedRoundNumbers.isNotEmpty
            ? Border.all(color: AppTheme.mauve.withValues(alpha: 0.12))
            : null,
      ),
      child: panelLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [dragHandle, promptText]),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [dragHandle, promptText, actions],
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
  final focusNode = FocusNode();
  final formKey = GlobalKey<FormState>();
  var focusScheduled = false;
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        if (!focusScheduled) {
          focusScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (focusNode.canRequestFocus) focusNode.requestFocus();
          });
        }
        return ConfirmationDialog(
          title: initialText == null ? 'Add prompt' : 'Edit prompt',
          content: 'Enter a discussion prompt for this Session.',
          confirmButtonText: 'Save',
          type: ConfirmationDialogType.standard,
          contentWidget: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
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
        );
      },
    );
  } finally {
    focusNode.dispose();
    controller.dispose();
  }
}
