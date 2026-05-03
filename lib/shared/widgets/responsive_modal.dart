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
  Color bottomSheetBackgroundColor = const Color(0xFFF3F1E9),
  Color dialogBackgroundColor = const Color(0xFFF3F1E9),
  Color? dialogBarrierColor,
  ShapeBorder? dialogShape,
  AlignmentGeometry dialogAlignment = Alignment.center,
  EdgeInsetsGeometry dialogInsetPadding = const EdgeInsets.all(24),
}) {
  assert(
    debugCheckHasDirectionality(context),
    'A Directionality widget is required to show a responsive modal.',
  );
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
        barrierColor: dialogBarrierColor,
        fullscreenDialog: true,
        builder: (context) => Dialog(
          alignment: dialogAlignment,
          constraints: const BoxConstraints(maxWidth: 600),
          insetPadding: dialogInsetPadding.resolve(Directionality.of(context)),
          backgroundColor: dialogBackgroundColor,
          shape:
              dialogShape ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
          child: largeScreenBuilder(context),
        ),
      );
  }
}
