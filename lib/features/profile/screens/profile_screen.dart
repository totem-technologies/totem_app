import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Get user info from auth state
    final auth = ref.watch(authControllerProvider.notifier);
    final user = auth.user;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  spacing: 10,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 146),
                      child: Column(
                        spacing: 10,
                        children: [
                          const UserAvatar(),
                          Text(
                            user?.name ?? 'Welcome',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                    // TODO(bdlukaa): Add user stats
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '12',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Sessions joined'),
                          SizedBox(height: 20),
                          Text(
                            '2',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Spaces joined'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Account',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Profile',
              onTap: () {
                context.pushNamed(RouteNames.profileDetail);
              },
            ),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Subscribed Spaces',
              onTap: () {},
            ),
            ProfileTile(
              icon: const Icon(Icons.history),
              title: 'Session history',
              onTap: () {},
            ),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Logout',
              onTap: auth.logout,
            ),
            Text(
              'Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Feedback',
              onTap: () {},
            ),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Privacy Policy',
              onTap: () {},
            ),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Terms',
              onTap: () {},
            ),
            ProfileTile(
              icon: const Icon(Icons.person),
              title: 'Delete account',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: Row(
            spacing: 10,
            children: [
              icon,
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.navigate_next_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
