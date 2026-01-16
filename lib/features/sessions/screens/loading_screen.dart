import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/circle_icon_button.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class LoadingRoomScreen extends StatelessWidget {
  const LoadingRoomScreen({super.key, this.actionBarKey});

  final Key? actionBarKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrejoinRoomBaseScreen(
      title: 'Connecting...',
      video: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        clipBehavior: Clip.hardEdge,
        child: const AspectRatio(
          aspectRatio: 16 / 21,
          child: LoadingVideoPlaceholder(),
        ),
      ),
      actionBar: ActionBar(
        key: actionBarKey,
        children: const [
          ActionBarButton(
            onPressed: null,
            child: LoadingIndicator(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class PrejoinRoomBaseScreen extends StatelessWidget {
  const PrejoinRoomBaseScreen({
    required this.title,
    required this.video,
    required this.actionBar,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget video;
  final Widget actionBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoomBackground(
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: CircleIconButton(
              margin: const EdgeInsetsDirectional.only(start: 20, top: 20),
              icon: TotemIcons.arrowBack,
              tooltip: MaterialLocalizations.of(
                context,
              ).backButtonTooltip,
              onPressed: () => popOrHome(context),
            ),
          ),
          extendBodyBehindAppBar: false,
          body: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                  child: Text(
                    subtitle ?? '\n',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsetsDirectional.symmetric(
                      horizontal: 40,
                      vertical: 10,
                    ),
                    alignment: Alignment.center,
                    child: video,
                  ),
                ),
                actionBar,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingVideoPlaceholder extends StatelessWidget {
  const LoadingVideoPlaceholder({super.key, this.borderRadius});

  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade500,
      period: const Duration(seconds: 1),
      direction: Directionality.of(context) == TextDirection.ltr
          ? ShimmerDirection.ltr
          : ShimmerDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(borderRadius ?? 28),
        ),
      ),
    );
  }
}
