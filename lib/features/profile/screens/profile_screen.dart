import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';

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
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                spacing: 10,
                children: [
                  ClipOval(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          user?.profileImage == null
                              ? null
                              : CachedNetworkImageProvider(user!.profileImage!),
                      child:
                          user?.profileImage == null
                              ? AnimatedBoringAvatar(
                                name: user!.profileAvatarSeed,
                                type: BoringAvatarType.beam,
                                duration: const Duration(milliseconds: 300),
                              )
                              : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      user?.name ?? 'Welcome',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              ProfileTile(
                icon: const Icon(Icons.person),
                title: 'Profile',
                onTap: () {},
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
                title: 'Profile',
                onTap: () {},
              ),
              const Spacer(),
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
    return Container(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const Icon(Icons.navigate_next_rounded),
        ],
      ),
    );
  }
}
