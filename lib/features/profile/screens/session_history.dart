import 'package:flutter/material.dart';
import 'package:totem_app/navigation/app_router.dart';

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Text(
                'Session History',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const Text(
                'You have not joined any Spaces yet.',
                textAlign: TextAlign.center,
              ),
              ElevatedButton(
                onPressed: () {
                  shellNavigatorKey.currentState?.goBranch(
                    MainRoutes.spaces.index,
                  );
                },
                child: const Text('Browse Spaces'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
