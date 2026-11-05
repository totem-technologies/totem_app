import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/session_dock_surface.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// White card used by [JoinTransitionCard] on the pre-join screen.
class _TransitionCardContainer extends StatelessWidget {
  const _TransitionCardContainer({
    required this.children,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    this.constraints = const BoxConstraints(maxWidth: 650),
  });

  final EdgeInsetsGeometry margin;
  final List<Widget> children;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: constraints,
      child: Card(
        margin: margin,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          // Hug content so the slider stays its own height instead of
          // expanding to fill the viewport.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// In-session cards (pass, receive, waiting, prompt) dock into the slate
/// chrome above the action bar as a glass pill sharing the action bar's
/// styling, on every viewport.
///
/// Phones keep the 48dp Material touch minimum for the slider (matching the
/// action bar's phone metrics, TOT-1398); larger viewports match the action
/// bar's 44dp comfortable buttons.
double _dockedActionHeight(BuildContext context) {
  return _isSmallViewport(context) ? 48 : 44;
}

bool _isSmallViewport(BuildContext context) {
  return ViewportResolver.getViewportKind(context).isSmall;
}

/// Label for the docked actions: the action bar's size on every device.
/// Other [ActionSliderButton] uses (Join) keep their default label.
TextStyle? _dockedActionLabelStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelLarge;
}

const _dockedInset = 6.0;
const _dockedTextInset = 20.0;

/// Pill width below which the action drops under the instruction.
///
/// Small viewports switch at 500, where the Pass instruction still gets two
/// readable lines beside a 240dp slider.
///
/// Medium viewports stay at 400 so they keep the desktop row: the speaking
/// screen pads 60dp per side, so a 601dp window leaves only a ~421dp pill.
/// Raising this to 500 would stack desktop pills on 601–680dp windows.
double _dockedInlineMinWidth(BuildContext context) {
  return _isSmallViewport(context) ? 500 : 400;
}

class _DockedTransitionCardContainer extends StatelessWidget {
  const _DockedTransitionCardContainer({
    required this.actionHeight,
    this.instruction,
    this.field,
    this.action,
    this.inlineActionConstraints = const BoxConstraints(
      minWidth: 140,
      maxWidth: 240,
    ),
    this.flexibleInlineAction = false,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
  }) : assert(
         (instruction == null) != (field == null),
         'Provide exactly one of instruction or field',
       );

  /// Instruction text, inset like the action bar's labels.
  final String? instruction;

  /// The keeper's prompt field. Its filled background carries its own
  /// rounding, so it hugs the pill.
  final Widget? field;
  final Widget? action;
  final double actionHeight;

  /// Width bounds for [action] when it sits beside the instruction; the
  /// touch slider needs a finite max.
  final BoxConstraints inlineActionConstraints;

  /// Lets the action share leftover width with the field instead of staying
  /// at its bounded width.
  final bool flexibleInlineAction;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final instruction = this.instruction;
    final inlineMinWidth = _dockedInlineMinWidth(context);
    return ConstrainedBox(
      // Inline pills are the same height with or without an action, so
      // pass -> waiting doesn't shift on larger viewports. A stacked phone
      // pill is taller than the single-row waiting pill.
      constraints: BoxConstraints(
        maxWidth: 650,
        minHeight: actionHeight + _dockedInset * 2,
      ),
      child: Padding(
        padding: margin,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inline =
                action == null || constraints.maxWidth >= inlineMinWidth;
            if (inline) {
              final textInset = instruction != null
                  ? _dockedTextInset
                  : _dockedInset;
              return DecoratedBox(
                decoration: sessionDockDecoration(onLightBackground: false),
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: textInset,
                    end: action == null ? textInset : _dockedInset,
                    top: _dockedInset,
                    bottom: _dockedInset,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      Flexible(
                        child: instruction != null
                            ? _DockedInstructionText(instruction, maxLines: 2)
                            : field!,
                      ),
                      if (action != null)
                        if (flexibleInlineAction)
                          Flexible(
                            child: ConstrainedBox(
                              constraints: inlineActionConstraints,
                              child: action,
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: inlineActionConstraints,
                            child: action,
                          ),
                    ],
                  ),
                ),
              );
            }

            // Stacked: same glass surface, with the corner radius kept
            // concentric with the full-width action below the instruction.
            return DecoratedBox(
              decoration: sessionDockDecoration(
                onLightBackground: false,
                radius: actionHeight / 2 + _dockedInset,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(_dockedInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    if (instruction != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          _dockedTextInset - _dockedInset,
                          _dockedInset,
                          _dockedTextInset - _dockedInset,
                          0,
                        ),
                        // The full pill width is available, so large text
                        // scales get a third line instead of being cut.
                        child: _DockedInstructionText(instruction, maxLines: 3),
                      )
                    else
                      field!,
                    SizedBox(height: actionHeight, child: action),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DockedInstructionText extends StatelessWidget {
  const _DockedInstructionText(this.text, {required this.maxLines});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: AutoSizeText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.cream),
        textAlign: TextAlign.center,
        maxLines: maxLines,
        minFontSize: 12,
      ),
    );
  }
}

class _TransitionCardBase extends StatefulWidget {
  const _TransitionCardBase({
    required this.childBuilder,
    this.keyboardShortcutText,
  });

  final Widget Function(BuildContext context, bool hasMouseConnected)
  childBuilder;
  final String? keyboardShortcutText;

  @override
  State<_TransitionCardBase> createState() => _TransitionCardBaseState();
}

class _TransitionCardBaseState extends State<_TransitionCardBase> {
  late bool _hasMouseConnected;
  late bool _hasKeyboardConnected;

  @override
  void initState() {
    super.initState();

    // Platform check is stable — unlike mouseIsConnected, it doesn't flicker
    // when the pointer leaves the browser window.
    _hasMouseConnected =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    // TODO(totem): Properly check for hardware keyboard.
    // Update this check when https://github.com/flutter/flutter/issues/185479 is addressed
    _hasKeyboardConnected = _hasMouseConnected;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showShortcut =
        _hasKeyboardConnected && widget.keyboardShortcutText != null;
    final card = widget.childBuilder(context, _hasMouseConnected);

    if (showShortcut) {
      return Column(
        spacing: 6,
        children: [
          card,
          Text(
            widget.keyboardShortcutText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF787D7E),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

class _GenericTransitionCard extends StatelessWidget {
  const _GenericTransitionCard({
    required this.actionText,
    required this.onActionPressed,
    required this.instructionTextClick,
    required this.instructionTextSwipe,
    this.keyboardShortcutText,
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
  });

  final String actionText;
  final OnActionPerformed? onActionPressed;
  final String instructionTextClick;
  final String instructionTextSwipe;
  final String? keyboardShortcutText;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final actionHeight = _dockedActionHeight(context);
    return _TransitionCardBase(
      keyboardShortcutText: keyboardShortcutText,
      childBuilder: (context, hasMouseConnected) {
        final instruction = hasMouseConnected
            ? instructionTextClick
            : instructionTextSwipe;
        return _DockedTransitionCardContainer(
          margin: margin,
          actionHeight: actionHeight,
          instruction: instruction,
          action: onActionPressed == null
              ? null
              : ActionSliderButton(
                  text: actionText,
                  onActionCompleted: onActionPressed!,
                  keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                  isLoading: isSliderLoading,
                  height: actionHeight,
                  labelStyle: _dockedActionLabelStyle(context),
                ),
        );
      },
    );
  }
}

class JoinTransitionCard extends StatelessWidget {
  const JoinTransitionCard({
    required this.onActionPressed,
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    this.enabled = true,
    this.note,
    this.waiting = false,
    this.waitingMessage,
    this.onLeaveWaiting,
    super.key,
  });

  final OnActionPerformed onActionPressed;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;
  final bool enabled;
  final String? note;
  final bool waiting;
  final String? waitingMessage;
  final VoidCallback? onLeaveWaiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TransitionCardBase(
      keyboardShortcutText: enabled && !waiting
          ? 'press space bar to join'
          : null,
      childBuilder: (context, _) {
        return _TransitionCardContainer(
          margin: margin,
          constraints: const BoxConstraints(maxWidth: 366),
          children: [
            Text(
              waiting ? 'Waiting to join' : 'Welcome',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              waiting
                  ? waitingMessage ??
                        'The Keeper will let you in. Your camera and microphone are only a local preview.'
                  : 'Your session will start soon. Please check your audio and video before joining.',
              textAlign: TextAlign.center,
            ),
            if (!waiting && note != null)
              Text(
                note!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            SizedBox(
              height: 52,
              child: waiting
                  ? OutlinedButton(
                      onPressed: onLeaveWaiting,
                      child: const Text('Leave waiting room'),
                    )
                  : ActionSliderButton(
                      text: 'Join',
                      onActionCompleted: onActionPressed,
                      keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                      isLoading: isSliderLoading,
                      enabled: enabled,
                      height: 52,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class PassTransitionCard extends StatelessWidget {
  const PassTransitionCard({
    required this.onActionPressed,
    this.actionText = 'Pass',
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final OnActionPerformed onActionPressed;
  final String actionText;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return _GenericTransitionCard(
      actionText: actionText,
      onActionPressed: onActionPressed,
      instructionTextClick:
          'When done, click to pass the Totem to the next person.',
      instructionTextSwipe:
          'When done, slide to pass the Totem to the next person.',
      keyboardShortcutText: 'press space bar to pass',
      // Keep the control busy after a successful pass so it can't be
      // double-triggered while the room transitions.
      keepActionLoadingOnSuccess: true,
      isSliderLoading: isSliderLoading,
      margin: margin,
    );
  }
}

class ReceiveTransitionCard extends StatelessWidget {
  const ReceiveTransitionCard({
    required this.onActionPressed,
    this.actionText = 'Receive',
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final OnActionPerformed onActionPressed;
  final String actionText;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return _GenericTransitionCard(
      actionText: actionText,
      onActionPressed: onActionPressed,
      instructionTextClick: 'The Totem is being passed to you.',
      instructionTextSwipe: 'The Totem is being passed to you.',
      keyboardShortcutText: 'press space bar to receive',
      keepActionLoadingOnSuccess: keepActionLoadingOnSuccess,
      isSliderLoading: isSliderLoading,
      margin: margin,
    );
  }
}

class StartTransitionCard extends StatelessWidget {
  const StartTransitionCard({
    required this.onActionPressed,
    this.actionText = 'Start session',
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final OnActionPerformed onActionPressed;
  final String actionText;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return _GenericTransitionCard(
      actionText: actionText,
      onActionPressed: onActionPressed,
      instructionTextClick:
          'Bring participants out of the waiting room and begin the conversation.',
      instructionTextSwipe:
          'Bring participants out of the waiting room and begin the conversation.',
      keyboardShortcutText: 'press space bar to start',
      keepActionLoadingOnSuccess: keepActionLoadingOnSuccess,
      isSliderLoading: isSliderLoading,
      margin: margin,
    );
  }
}

class WaitingReceiveTransitionCard extends StatelessWidget {
  const WaitingReceiveTransitionCard({
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    const message = 'Waiting for the receiver to accept.';
    return _GenericTransitionCard(
      actionText: '',
      onActionPressed: null,
      instructionTextClick: message,
      instructionTextSwipe: message,
      keyboardShortcutText: null,
      margin: margin,
    );
  }
}

class PromptTransitionCard extends StatefulWidget {
  const PromptTransitionCard({
    required this.onActionPressed,
    this.initialPrompt,
    this.initialSessionPromptId,
    this.onManagePrompts,
    this.actionText = 'Pass',
    this.keepActionLoadingOnSuccess = true,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final Future<bool> Function({
    String? customPrompt,
    int? sessionPromptId,
    bool clearPrompt,
  })
  onActionPressed;
  final String? initialPrompt;
  final int? initialSessionPromptId;
  final VoidCallback? onManagePrompts;
  final String actionText;
  final bool keepActionLoadingOnSuccess;
  final EdgeInsetsGeometry margin;

  @override
  State<PromptTransitionCard> createState() => _PromptTransitionCardState();
}

class _PromptTransitionCardState extends State<PromptTransitionCard> {
  late final TextEditingController customPromptController =
      TextEditingController(text: widget.initialPrompt ?? '');
  String _lastInitialPrompt = '';

  final textFieldFocusNode = FocusNode();
  final buttonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _lastInitialPrompt = widget.initialPrompt ?? '';
    textFieldFocusNode.addListener(_textFieldFocusNodeListener);
  }

  @override
  void didUpdateWidget(covariant PromptTransitionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextInitialPrompt = widget.initialPrompt ?? '';
    if (nextInitialPrompt != _lastInitialPrompt &&
        customPromptController.text == _lastInitialPrompt) {
      customPromptController.value = TextEditingValue(
        text: nextInitialPrompt,
        selection: TextSelection.collapsed(offset: nextInitialPrompt.length),
      );
    }
    _lastInitialPrompt = nextInitialPrompt;
  }

  void _textFieldFocusNodeListener() {
    if (!textFieldFocusNode.hasFocus) {
      buttonFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    customPromptController.dispose();
    textFieldFocusNode.dispose();
    buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionHeight = _dockedActionHeight(context);
    return _TransitionCardBase(
      keyboardShortcutText: null,
      childBuilder: (context, _) {
        Future<bool> onPromptAction() {
          final prompt = customPromptController.text.trim();
          if (prompt == _lastInitialPrompt.trim()) {
            // Passing does not re-select the current prepared prompt.
            return widget.onActionPressed();
          }
          return widget.onActionPressed(
            customPrompt: prompt.isEmpty ? null : prompt,
            clearPrompt: prompt.isEmpty,
          );
        }

        final promptField = TextField(
          controller: customPromptController,
          decoration: InputDecoration(
            hintText: 'Your prompt for this round',
            suffixIcon: widget.onManagePrompts == null
                ? null
                : IconButton(
                    tooltip: 'Manage discussion prompts',
                    onPressed: widget.onManagePrompts,
                    icon: const TotemIcon(
                      TotemIcons.edit,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          selectAllOnFocus: true,
          focusNode: textFieldFocusNode,
          onTapOutside: (_) {
            buttonFocusNode.requestFocus();
          },
        );
        return _DockedTransitionCardContainer(
          margin: widget.margin,
          actionHeight: actionHeight,
          field: promptField,
          inlineActionConstraints: const BoxConstraints(minWidth: 200),
          flexibleInlineAction: true,
          action: ActionSliderButton(
            text: widget.actionText,
            height: actionHeight,
            onActionCompleted: onPromptAction,
            keepLoadingOnSuccess: widget.keepActionLoadingOnSuccess,
            focusNode: buttonFocusNode,
            labelStyle: _dockedActionLabelStyle(context),
          ),
        );
      },
    );
  }
}
