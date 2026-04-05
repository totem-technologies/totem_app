import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/circle_icon_button.dart';

class PrejoinRoomBaseScreen extends StatelessWidget {
  const PrejoinRoomBaseScreen({
    required this.video,
    required this.actionBar,
    this.joinSlider,
    super.key,
  });

  final Widget video;
  final Widget? joinSlider;
  final Widget actionBar;

  @override
  Widget build(BuildContext context) {
    return RoomBackground(
      child: Builder(
        builder: (context) {
          return SafeArea(
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
                  spacing: 18,
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 40,
                          // vertical: 10,
                        ),
                        alignment: AlignmentDirectional.center,
                        child: video,
                      ),
                    ),
                    // SizedBox needed to maintain padding with and without it.
                    joinSlider ?? const SizedBox(),
                    actionBar,
                  ],
                ),
              ),
            ),
          );
        },
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
