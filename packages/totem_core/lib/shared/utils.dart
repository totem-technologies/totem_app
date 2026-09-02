import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SeatsLeftText extends StatelessWidget {
  const SeatsLeftText({
    required this.seatsLeft,
    super.key,
  });

  final int seatsLeft;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: seatsLeft == 0 ? 'No' : '$seatsLeft',
          ),
          TextSpan(
            text: seatsLeft == 1 ? ' seat left' : ' seats left',
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.fade,
    );
  }
}

/// Whether the app is currently not rendering frames, e.g. a backgrounded
/// browser tab or a paused mobile app. Overlay entries inserted in this
/// state stay unbuilt until the app becomes visible again.
bool isAppHidden() {
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  return lifecycle == AppLifecycleState.hidden ||
      lifecycle == AppLifecycleState.paused ||
      lifecycle == AppLifecycleState.detached;
}

extension WidgetRefExtension on WidgetRef {
  void sentryReportFullyDisplayed<T>(ProviderListenable<T> provider) {
    listen(provider, (old, _) {
      if (old == null) SentryDisplayWidget.of(context).reportFullyDisplayed();
    });
  }
}
