import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:totem_app/shared/totem_icons.dart';

Future<void> showDownloadMobileAppDialog(BuildContext context) {
  if (kIsWeb) {
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
    const appStoreButton = SizedBox.shrink();
    const playStoreButton = SizedBox.shrink();
    return AlertDialog(
      title: const Column(
        children: [
          TotemIcon(TotemIcons.downloadApp, size: 60),
          Text('Download Mobile App'),
        ],
      ),
      content: Column(
        spacing: 10,
        children: [
          const Text(
            'Download our app to join this session on your mobile device for the best experience.',
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
