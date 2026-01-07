import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Widget buildSeatsLeftText(int seatsLeft) {
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

extension WidgetRefExtension on WidgetRef {
  void sentryReportFullyDisplayed<T>(ProviderListenable<T> provider) {
    listen(provider, (old, _) {
      if (old == null) SentryDisplayWidget.of(context).reportFullyDisplayed();
    });
  }
}
