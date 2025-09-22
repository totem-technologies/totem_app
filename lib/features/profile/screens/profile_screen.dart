import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/features/profile/screens/delete_account.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:url_launcher/link.dart';

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
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: SafeArea(
        top: false,
        bottom: false,
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
                          UserAvatar.currentUser(),
                          AutoSizeText(
                            user?.name ?? 'Welcome',
                            style: theme.textTheme.headlineMedium,
                            maxLines: 1,
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
              icon: const TotemIcon(TotemIcons.profile),
              title: 'Profile',
              onTap: () {
                context.pushNamed(RouteNames.profileDetail);
              },
            ),
            ProfileTile(
              icon: const TotemIcon(TotemIcons.subscribedSpaces),
              title: 'Subscribed Spaces',
              onTap: () {
                context.pushNamed(RouteNames.subscribedSpaces);
              },
            ),
            ProfileTile(
              icon: const TotemIcon(TotemIcons.history),
              title: 'Session history',
              onTap: () {
                context.pushNamed(RouteNames.sessionHistory);
              },
            ),
            ProfileTile(
              icon: const TotemIcon(TotemIcons.logout),
              title: 'Logout',
              onTap: () => showLogoutDialog(context),
            ),
            Text(
              'Help',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Link(
              uri: Uri.parse(
                AppConfig.mobileApiUrl,
              ).resolve('/users/feedback/'),
              target: LinkTarget.self,
              builder: (context, launch) => ProfileTile(
                icon: const TotemIcon(TotemIcons.feedback),
                title: 'Feedback',
                onTap: () => launch?.call(),
              ),
            ),
            Link(
              uri: AppConfig.privacyPolicyUrl,
              builder: (context, launch) => ProfileTile(
                icon: const TotemIcon(TotemIcons.lock),
                title: 'Privacy Policy',
                onTap: () => launch?.call(),
              ),
            ),
            Link(
              uri: AppConfig.termsOfServiceUrl,
              builder: (context, launch) => ProfileTile(
                icon: const TotemIcon(TotemIcons.safe),
                title: 'Terms',
                onTap: () => launch?.call(),
              ),
            ),
            Link(
              uri: AppConfig.communityGuidelinesUrl,
              builder: (context, launch) => ProfileTile(
                icon: const TotemIcon(TotemIcons.community),
                title: 'Community Guidelines',
                onTap: () => launch?.call(),
              ),
            ),
            ProfileTile(
              icon: const TotemIcon(TotemIcons.closeRounded),
              title: 'Delete account',
              onTap: () => showDeleteAccountDialog(context),
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
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final Widget icon;
  final String title;
  final VoidCallback onTap;

  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: backgroundColor ?? Colors.white,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: Row(
            spacing: 10,
            children: [
              IconTheme.merge(
                data: IconThemeData(color: foregroundColor, size: 20),
                child: icon,
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: foregroundColor,
                  ),
                ),
              ),
              TotemIcon(
                TotemIcons.arrowForward,
                color: foregroundColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
