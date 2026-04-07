import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:totem_app/features/sessions/widgets/action_slider_button.dart';

enum TotemCardTransitionType { join, pass, receive, start, waitingReceive }

class TransitionCardContainer extends StatelessWidget {
  const TransitionCardContainer({
    required this.children,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final EdgeInsetsGeometry margin;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            margin: margin,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: 12,
                start: 16,
                end: 16,
                bottom: 16,
              ),
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

class TransitionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TransitionCardContainer(
      margin: margin,
      children: [
        if (type == TotemCardTransitionType.join)
          Flexible(
            child: Column(
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
              ],
            ),
          )
        else
          Flexible(
            child: AutoSizeText(
              switch (type) {
                TotemCardTransitionType.join => 'Swipe to join the session.',
                TotemCardTransitionType.pass =>
                  'When done, slide to pass the Totem to the next person.',
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
        if (type != TotemCardTransitionType.waitingReceive)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
              ),
              child: ActionSliderButton(
                text:
                    actionText ??
                    switch (type) {
                      TotemCardTransitionType.join => 'Join',
                      TotemCardTransitionType.pass => 'Pass',
                      TotemCardTransitionType.receive => 'Receive',
                      TotemCardTransitionType.start => 'Start Session',
                      TotemCardTransitionType.waitingReceive =>
                        throw UnsupportedError(
                          'This should never be reached',
                        ),
                    },
                onActionCompleted: onActionPressed,
                keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                isLoading: isSliderLoading,
              ),
            ),
          ),
      ],
    );
  }
}
