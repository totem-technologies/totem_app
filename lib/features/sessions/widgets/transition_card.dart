import 'package:flutter/material.dart';

enum TotemCardTransitionType { pass, receive }

class PassReceiveCard extends StatelessWidget {
  const PassReceiveCard({
    required this.type,
    required this.onActionPressed,
    super.key,
  });

  final TotemCardTransitionType type;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: 20,
          start: 30,
          end: 30,
          bottom: 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 15,
          children: [
            Text(
              switch (type) {
                TotemCardTransitionType.pass =>
                  'When done, press Pass to pass the Totem to the next person.',
                TotemCardTransitionType.receive =>
                  'Check camera & mic then tap Receive',
              },
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
              ),
              child: ElevatedButton(
                onPressed: onActionPressed,
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
                child: Text(
                  switch (type) {
                    TotemCardTransitionType.pass => 'Pass',
                    TotemCardTransitionType.receive => 'Receive',
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
