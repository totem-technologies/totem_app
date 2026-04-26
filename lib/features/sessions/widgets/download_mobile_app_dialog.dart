import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:url_launcher/link.dart';

Future<void> showDownloadMobileAppDialog(BuildContext context) {
  final shouldShow =
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (shouldShow) {
    return showDialog(
      context: context,
      builder: (context) => const DownloadMobileAppDialog(),
    );
  }
  return Future.value();
}

class DownloadMobileAppDialog extends StatelessWidget {
  const DownloadMobileAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStoreButton = Link(
      uri: Uri.parse('https://apps.apple.com/app/id6749549727'),
      builder: (context, followLink) {
        return GestureDetector(
          onTap: followLink,
          child: Image.asset(
            TotemImageAssets.downloadAppStore,
            height: 52,
          ),
        );
      },
    );
    final playStoreButton = Link(
      uri: Uri.parse(
        'https://play.google.com/store/apps/details?id=org.totem.app',
      ),
      builder: (context, followLink) {
        return GestureDetector(
          onTap: followLink,
          child: Image.asset(
            TotemImageAssets.downloadPlayStore,
            height: 52,
          ),
        );
      },
    );

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 300),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          TotemIcon(
            TotemIcons.downloadApp,
            size: 60,
            color: theme.colorScheme.primary,
            fillColor: false,
          ),
          const Text('Download Mobile App'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          Text(
            'Download our app to join this session on your mobile device for the best experience.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (defaultTargetPlatform == TargetPlatform.iOS)
            appStoreButton
          else if (defaultTargetPlatform == TargetPlatform.android)
            playStoreButton
          else ...[
            appStoreButton,
            playStoreButton,
          ],
        ],
      ),
    );
  }
}
