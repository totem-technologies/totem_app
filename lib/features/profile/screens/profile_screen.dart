import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;

  // Implement logout functionality
  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Call the logout method from auth controller
      await ref.read(authControllerProvider.notifier).logout();

      // Navigation will be handled automatically by router's redirect
      // when auth state changes to unauthenticated
    } catch (e) {
      // Handle any logout errors
      if (mounted) {
        await ErrorHandler.handleApiError(context, e, onRetry: _logout);
      }
    } finally {
      // In case we're still mounted and logout failed
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get user info from auth state
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
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

            // Display user name if available
            if (user != null && user.name != null)
              Text(
                'Hello, ${user.name}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text('Profile Screen', style: TextStyle(fontSize: 24)),

            // Display user email if available
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  user.email,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                context.go(RouteNames.spaces);
              },
              child: const Text('Back to Spaces'),
            ),

            const SizedBox(height: 16),

            // Logout button with loading state
            ElevatedButton(
              onPressed: _isLoggingOut ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child:
                  _isLoggingOut
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
