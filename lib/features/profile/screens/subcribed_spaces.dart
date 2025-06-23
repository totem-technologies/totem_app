import 'package:flutter/material.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SubscribedSpacesScreen extends StatelessWidget {
  const SubscribedSpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final spaces = <String>[];

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: spaces.isEmpty
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Text(
                'Subscribed Spaces',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              Text(
                spaces.isEmpty
                    ? 'You are not subscribed to any Spaces.'
                    : 'These are the Spaces you will get notifications for '
                          'when new sessions are coming up.',
                textAlign: TextAlign.center,
              ),
              if (spaces.isEmpty)
                ElevatedButton(
                  onPressed: () {
                    toHome(HomeRoutes.spaces);
                  },
                  child: const Text('Browse Spaces'),
                )
              else
                for (final space in spaces)
                  GestureDetector(
                    onTap: () {
                      // TODO(bdlukaa): On unsubscribe from space
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      padding: const EdgeInsetsDirectional.only(
                        top: 10,
                        start: 20,
                        bottom: 10,
                        end: 15,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(space)),
                          Container(
                            height: 35,
                            width: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Center(
                              child: TotemIcon(
                                TotemIcons.delete,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
