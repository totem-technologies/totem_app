import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: constraints.maxWidth < 500
                  ? const EdgeInsetsDirectional.only(
                      top: 12,
                      start: 16,
                      end: 16,
                      bottom: 16,
                    )
                  : const EdgeInsetsDirectional.all(16),
              child: Flex(
                direction: constraints.maxWidth < 500
                    ? Axis.vertical
                    : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                spacing: 15,
                children: children,
              ),
            ),
          );
        },
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
  late final MouseTracker _mouseTracker;
  late bool _hasMouseConnected;
  late bool _hasKeyboardConnected;

  @override
  void initState() {
    super.initState();
    _mouseTracker = RendererBinding.instance.mouseTracker;
    _hasMouseConnected = _mouseTracker.mouseIsConnected;

    // TODO(totem): Properly check for hardware keyboard.
    // Update this check when https://github.com/flutter/flutter/issues/185479 is addressed
    _hasKeyboardConnected =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    _mouseTracker.addListener(_handleMouseConnectionChanged);
  }

  @override
  void dispose() {
    _mouseTracker.removeListener(_handleMouseConnectionChanged);
    super.dispose();
  }

  void _handleMouseConnectionChanged() {
    final hasMouseConnected = _mouseTracker.mouseIsConnected;
    if (_hasMouseConnected == hasMouseConnected || !mounted) {
      return;
    }

    setState(() {
      _hasMouseConnected = hasMouseConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.childBuilder(context, _hasMouseConnected);

    if (_hasKeyboardConnected && widget.keyboardShortcutText != null) {
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
    return _TransitionCardBase(
      keyboardShortcutText: keyboardShortcutText,
      childBuilder: (context, hasMouseConnected) {
        return _TransitionCardContainer(
          margin: margin,
          children: [
            Flexible(
              child: AutoSizeText(
                hasMouseConnected ? instructionTextClick : instructionTextSwipe,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            if (onActionPressed != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 14,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 160),
                    child: ActionSliderButton(
                      text: actionText,
                      onActionCompleted: onActionPressed!,
                      keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                      isLoading: isSliderLoading,
                    ),
                  ),
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
    super.key,
  });

  final OnActionPerformed onActionPressed;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TransitionCardBase(
      keyboardShortcutText: 'press space bar to join',
      childBuilder: (context, hasMouseConnected) {
        return _TransitionCardContainer(
          margin: margin,
          constraints: const BoxConstraints(maxWidth: 366),
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
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
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 160),
                      child: ActionSliderButton(
                        text: 'Join',
                        onActionCompleted: onActionPressed,
                        keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                        isLoading: isSliderLoading,
                      ),
                    ),
                  ),
                ],
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
      keepActionLoadingOnSuccess: keepActionLoadingOnSuccess,
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
    this.actionText = 'Start Session',
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
    return _GenericTransitionCard(
      actionText: '',
      onActionPressed: null,
      instructionTextClick:
          'Waiting for the receiver to accept...\nIt is still your turn',
      instructionTextSwipe:
          'Waiting for the receiver to accept...\nIt is still your turn',
      keyboardShortcutText: null,
      margin: margin,
    );
  }
}

class PromptTransitionCard extends StatefulWidget {
  const PromptTransitionCard({
    required this.onActionPressed,
    this.actionText = 'Pass',
    this.keepActionLoadingOnSuccess = true,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final Future<bool> Function(String message) onActionPressed;
  final String actionText;
  final bool keepActionLoadingOnSuccess;
  final EdgeInsetsGeometry margin;

  @override
  State<PromptTransitionCard> createState() => _PromptTransitionCardState();
}

class _PromptTransitionCardState extends State<PromptTransitionCard> {
  final roundMessageController = TextEditingController();

  @override
  void dispose() {
    roundMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TransitionCardBase(
      keyboardShortcutText: null,
      childBuilder: (context, hasMouseConnected) {
        return _TransitionCardContainer(
          margin: widget.margin,
          children: [
            Flexible(
              child: TextField(
                controller: roundMessageController,
                decoration: const InputDecoration(
                  hintText: 'Your prompt for this round',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 160,
                ),
                child: ActionSliderButton(
                  text: widget.actionText,
                  onActionCompleted: () {
                    return widget.onActionPressed(
                      roundMessageController.text.trim(),
                    );
                  },
                  keepLoadingOnSuccess: widget.keepActionLoadingOnSuccess,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
