import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/l10n/app_localizations.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CardScreen(
      showBackground: true,
      showLogoOnLargeScreens: false,
      children: [
        Image.asset('assets/logo/logo-black.png'),
        Text(l10n.turnConversationsIntoCommunity),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            context.go(RouteNames.login);
          },
          child: Text(l10n.getStarted, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
