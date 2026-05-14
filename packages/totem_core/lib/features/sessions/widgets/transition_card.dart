import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';

enum TotemCardTransitionType { join, pass, receive, start, waitingReceive }

class TransitionCardContainer extends StatelessWidget {
  const TransitionCardContainer({
    required this.children,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    this.constraints = const BoxConstraints(maxWidth: 650),
    super.key,
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

class TransitionCard extends StatefulWidget {
  const TransitionCard({
    required this.type,
    required this.onActionPressed,
    this.actionText,
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final TotemCardTransitionType type;
  final OnActionPerformed onActionPressed;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;

  final EdgeInsetsGeometry margin;
  final String? actionText;

  @override
  State<TransitionCard> createState() => _TransitionCardState();
}

class _TransitionCardState extends State<TransitionCard> {
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
    final shouldShowActionButton =
        widget.type != TotemCardTransitionType.waitingReceive;

    final buttonText =
        widget.actionText ??
        switch (widget.type) {
          TotemCardTransitionType.join => 'Join',
          TotemCardTransitionType.pass => 'Pass',
          TotemCardTransitionType.receive => 'Receive',
          TotemCardTransitionType.start => 'Start Session',
          TotemCardTransitionType.waitingReceive => '',
        };

    final actionButton = shouldShowActionButton
        ? Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
              ),
              child: ActionSliderButton(
                text: buttonText,
                onActionCompleted: widget.onActionPressed,
                keepLoadingOnSuccess: widget.keepActionLoadingOnSuccess,
                isLoading: widget.isSliderLoading,
              ),
            ),
          )
        : null;

    final card = TransitionCardContainer(
      margin: widget.margin,
      constraints: switch (widget.type) {
        TotemCardTransitionType.join => const BoxConstraints(maxWidth: 366),
        _ => const BoxConstraints(maxWidth: 650),
      },
      children: [
        if (widget.type == TotemCardTransitionType.join)
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
                ?actionButton,
              ],
            ),
          )
        else
          Flexible(
            child: AutoSizeText(
              switch (widget.type) {
                TotemCardTransitionType.join =>
                  _hasMouseConnected
                      ? 'Click to join the session.'
                      : 'Swipe to join the session.',
                TotemCardTransitionType.pass =>
                  _hasMouseConnected
                      ? 'When done, click to pass the Totem to the next person.'
                      : 'When done, slide to pass the Totem to the next person.',
                TotemCardTransitionType.receive =>
                  'The Totem is being passed to you.',
                TotemCardTransitionType.start =>
                  'Bring participants out of the waiting room and begin '
                      'the conversation.',
                TotemCardTransitionType.waitingReceive =>
                  'Waiting for the receiver to accept...\n'
                      'It is still your turn',
              },
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        if (actionButton != null && widget.type != TotemCardTransitionType.join)
          Flexible(child: actionButton),
      ],
    );

    if (_hasKeyboardConnected &&
        widget.type != TotemCardTransitionType.waitingReceive &&
        widget.type != TotemCardTransitionType.join) {
      return Column(
        spacing: 6,
        children: [
          card,
          Text(
            switch (widget.type) {
              TotemCardTransitionType.join => 'press space bar to join',
              TotemCardTransitionType.pass => 'press space bar to pass',
              TotemCardTransitionType.receive => 'press space bar to receive',
              TotemCardTransitionType.start => 'press space bar to start',
              TotemCardTransitionType.waitingReceive =>
                throw UnimplementedError(),
            },
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
