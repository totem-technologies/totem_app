import 'package:flutter/widgets.dart';

/// Routes opened by docked content still belong to the room navigator.
class SessionNavigatorScope extends InheritedWidget {
  const SessionNavigatorScope({
    required this.navigatorKey,
    required super.child,
    super.key,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  bool updateShouldNotify(SessionNavigatorScope oldWidget) =>
      navigatorKey != oldWidget.navigatorKey;
}

BuildContext sessionNavigatorContext(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<SessionNavigatorScope>()
        ?.navigatorKey
        .currentContext ??
    context;
