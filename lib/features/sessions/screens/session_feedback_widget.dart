import 'package:flutter/material.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SessionFeedbackWidget extends StatelessWidget {
  const SessionFeedbackWidget({
    required this.onThumbUpPressed,
    required this.onThumbDownPressed,
    super.key,
  });

  final VoidCallback onThumbUpPressed;
  final VoidCallback onThumbDownPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 130,
            child: Text(
              'How was your experience?',
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              _SessionFeedbackButton(
                icon: const TotemIcon(
                  TotemIcons.thumbUp,
                  color: Colors.white,
                ),
                onPressed: onThumbDownPressed,
              ),
              _SessionFeedbackButton(
                icon: const TotemIcon(
                  TotemIcons.thumbDown,
                  color: Colors.white,
                ),
                onPressed: onThumbDownPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionFeedbackButton extends StatelessWidget {
  const _SessionFeedbackButton({
    required this.icon,
    required this.onPressed,
  });

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsetsDirectional.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: icon,
      ),
    );
  }
}
