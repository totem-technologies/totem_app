import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';

class ActionBarSpeakerButton extends StatelessWidget {
  const ActionBarSpeakerButton({
    required this.isSpeakerOn,
    required this.onSpeakerToggled,
    super.key,
  });

  final bool isSpeakerOn;
  final ValueChanged<bool>? onSpeakerToggled;

  @override
  Widget build(BuildContext context) {
    return ActionBarButton(
      semanticsLabel: 'Audio ${isSpeakerOn ? 'on' : 'off'}',
      onPressed: onSpeakerToggled == null
          ? null
          : () => onSpeakerToggled?.call(!isSpeakerOn),
      active: isSpeakerOn,
      child: TotemIcon(
        isSpeakerOn ? TotemIcons.speakerOn : TotemIcons.speakerOff,
      ),
    );
  }
}
