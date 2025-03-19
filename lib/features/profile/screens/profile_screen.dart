import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings or notification settings
              context.push('/notifications/settings');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 80),
            const SizedBox(height: 16),
            const Text('Profile Screen', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Simple navigation back to spaces
                context.go('/spaces');
              },
              child: const Text('Back to Spaces'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Log out would be implemented here
                // Call the auth controller to log out
                context.go('/auth/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
