import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class LoadingRoomScreen extends StatelessWidget {
  const LoadingRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: RoomBackground(
        padding: const EdgeInsetsDirectional.all(20),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Connecting to this Space',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 20,
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Please wait while we prepare your audio and video '
                            'settings.\n'
                            '\n'
                            'Please take a moment to go over the',
                      ),
                      TextSpan(
                        text: '\ncommunity guidelines',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            launchUrl(AppConfig.communityGuidelinesUrl);
                          },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsetsDirectional.symmetric(
                    horizontal: 40,
                    vertical: 10,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: const AspectRatio(
                      aspectRatio: 16 / 21,
                      child: LoadingVideoPlaceholder(),
                    ),
                  ),
                ),
              ),
              const ActionBar(
                children: [
                  ActionBarButton(
                    onPressed: null,
                    child: LoadingIndicator(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingVideoPlaceholder extends StatelessWidget {
  const LoadingVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade900,
      highlightColor: Colors.grey.shade500,
      period: const Duration(seconds: 1),
      direction: Directionality.of(context) == TextDirection.ltr
          ? ShimmerDirection.ltr
          : ShimmerDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}
