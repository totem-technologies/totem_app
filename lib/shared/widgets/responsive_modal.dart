import 'package:flutter/material.dart';
import 'package:totem_app/shared/widgets/viewport_resolver.dart';

Future<T?> showResponsiveModal<T>({
  required BuildContext context,
  required WidgetBuilder smallScreenBuilder,
  required WidgetBuilder largeScreenBuilder,
  bool useRootNavigator = false,
  bool showDragHandle = false,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color bottomSheetBackgroundColor = Colors.white,
  Color dialogBackgroundColor = Colors.white,
  ShapeBorder? dialogShape,
  AlignmentGeometry dialogAlignment = Alignment.center,
  EdgeInsetsGeometry dialogInsetPadding = const EdgeInsets.all(24),
}) {
  switch (ViewportResolver.getViewportKind(context)) {
    case ViewportKind.smallPortrait:
    case ViewportKind.smallLandscape:
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        useSafeArea: useSafeArea,
        backgroundColor: bottomSheetBackgroundColor,
        useRootNavigator: useRootNavigator,
        builder: smallScreenBuilder,
      );
    case ViewportKind.mediumPlus:
      return showDialog<T>(
        context: context,
        useRootNavigator: useRootNavigator,
        builder: (context) => Dialog(
          alignment: dialogAlignment,
          insetPadding: dialogInsetPadding.resolve(Directionality.of(context)),
          backgroundColor: dialogBackgroundColor,
          shape:
              dialogShape ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
          child: largeScreenBuilder(context),
        ),
      );
  }
}
