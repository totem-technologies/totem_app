import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/session_dock_surface.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            margin: margin,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              // Portrait phones: hug content so the slider stays ~52px tall
              // instead of Flexible-expanding to fill the viewport.
              child: constraints.maxWidth < 500
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 14,
                      children: children,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 15,
                      children: [
                        for (final child in children) Flexible(child: child),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Large viewports dock in-session cards into the slate chrome above the
/// action bar instead of a white card, to give the video tiles more room.
/// Phones keep the white card.
bool _isDockedViewport(BuildContext context) {
  return switch (ViewportResolver.getViewportKind(context)) {
    ViewportKind.mediumSmall || ViewportKind.mediumPlus => true,
    ViewportKind.smallPortrait || ViewportKind.smallLandscape => false,
  };
}

/// Matches the action bar's comfortable button size.
const _dockedActionHeight = 44.0;
const _dockedInset = 6.0;

class _DockedTransitionCardContainer extends StatelessWidget {
  const _DockedTransitionCardContainer({
    required this.children,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    this.padding = const EdgeInsetsDirectional.only(
      start: 20,
      end: _dockedInset,
      top: _dockedInset,
      bottom: _dockedInset,
    ),
  });

  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Same height with or without an action, so pass -> waiting
      // doesn't shift the layout.
      constraints: const BoxConstraints(
        maxWidth: 650,
        minHeight: _dockedActionHeight + _dockedInset * 2,
      ),
      child: Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: sessionDockDecoration(onLightBackground: false),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _DockedInstructionText extends StatelessWidget {
  const _DockedInstructionText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: AutoSizeText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.cream),
        textAlign: TextAlign.center,
        maxLines: 2,
        minFontSize: 12,
      ),
    );
  }
}

/// Inline replacement for the "press space bar to ..." line below the
/// white card.
class _ShortcutKeyCap extends StatelessWidget {
  const _ShortcutKeyCap({required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cream.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          child: Text(
            'Space',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.cream.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitionCardBase extends StatefulWidget {
  const _TransitionCardBase({
    required this.childBuilder,
    this.keyboardShortcutText,
    this.inlineShortcut = false,
  });

  final Widget Function(
    BuildContext context,
    bool hasMouseConnected,
    bool showInlineShortcut,
  )
  childBuilder;
  final String? keyboardShortcutText;

  /// When true the card renders the shortcut itself (see [_ShortcutKeyCap])
  /// instead of a caption below it.
  final bool inlineShortcut;

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
    final card = widget.childBuilder(
      context,
      _hasMouseConnected,
      showShortcut && widget.inlineShortcut,
    );

    if (showShortcut && !widget.inlineShortcut) {
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
    final theme = Theme.of(context);
    final docked = _isDockedViewport(context);
    return _TransitionCardBase(
      keyboardShortcutText: keyboardShortcutText,
      inlineShortcut: docked,
      childBuilder: (context, hasMouseConnected, showInlineShortcut) {
        final instruction = hasMouseConnected
            ? instructionTextClick
            : instructionTextSwipe;
        if (docked) {
          return _DockedTransitionCardContainer(
            margin: margin,
            padding: onActionPressed == null
                ? const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                    vertical: _dockedInset,
                  )
                : const EdgeInsetsDirectional.only(
                    start: 20,
                    end: _dockedInset,
                    top: _dockedInset,
                    bottom: _dockedInset,
                  ),
            children: [
              Flexible(child: _DockedInstructionText(instruction)),
              if (onActionPressed != null) ...[
                if (showInlineShortcut)
                  _ShortcutKeyCap(semanticLabel: keyboardShortcutText!),
                // Bounded, not flexible, so the instruction keeps the
                // remaining width; the touch slider still needs a finite max.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 140,
                    maxWidth: 240,
                  ),
                  child: ActionSliderButton(
                    text: actionText,
                    onActionCompleted: onActionPressed!,
                    keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                    isLoading: isSliderLoading,
                    height: _dockedActionHeight,
                  ),
                ),
              ],
            ],
          );
        }
        return _TransitionCardContainer(
          margin: margin,
          children: [
            AutoSizeText(
              instruction,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            if (onActionPressed != null)
              SizedBox(
                height: 52,
                child: ActionSliderButton(
                  text: actionText,
                  onActionCompleted: onActionPressed!,
                  keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                  isLoading: isSliderLoading,
                  height: 52,
                ),
              ),
          ],
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
    super.key,
  });

  final OnActionPerformed onActionPressed;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TransitionCardBase(
      keyboardShortcutText: 'press space bar to join',
      childBuilder: (context, _, _) {
        return _TransitionCardContainer(
          margin: margin,
          constraints: const BoxConstraints(maxWidth: 366),
          children: [
            Text(
              'Welcome',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Your session will start soon. Please check your audio and video before joining.',
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 52,
              child: ActionSliderButton(
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
    final docked = _isDockedViewport(context);
    return _TransitionCardBase(
      keyboardShortcutText: null,
      childBuilder: (context, _, _) {
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
        final action = ActionSliderButton(
          text: widget.actionText,
          height: docked ? _dockedActionHeight : 52,
          onActionCompleted: onPromptAction,
          keepLoadingOnSuccess: widget.keepActionLoadingOnSuccess,
          focusNode: buttonFocusNode,
        );
        if (docked) {
          // The filled text field carries its own rounding, so hug it.
          return _DockedTransitionCardContainer(
            margin: widget.margin,
            padding: const EdgeInsetsDirectional.all(_dockedInset),
            children: [
              Flexible(child: promptField),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: action,
                ),
              ),
            ],
          );
        }
        return _TransitionCardContainer(
          margin: widget.margin,
          children: [
            promptField,
            SizedBox(height: 52, child: action),
          ],
        );
      },
    );
  }
}
