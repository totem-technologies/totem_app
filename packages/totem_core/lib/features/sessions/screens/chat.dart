import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/screens/session_chat_panel.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

export 'keeper_profile_sheet.dart';
export 'session_chat_panel.dart' show SessionChatPanel;

const String sessionChatRouteName = 'session-chat';

/// Dock the chat panel on wide tablet/desktop.
bool shouldDockSessionChat(BuildContext context) =>
    shouldDockSessionSidePanel(context);

Future<void> showSessionChat(BuildContext context) {
  switch (ViewportResolver.getViewportKind(context)) {
    case ViewportKind.smallPortrait:
    case ViewportKind.smallLandscape:
      // Phones already get the platform sheet slide; leave that path alone.
      return showResponsiveModal<void>(
        context: context,
        useRootNavigator: false,
        routeSettings: const RouteSettings(name: sessionChatRouteName),
        showDragHandle: false,
        useSafeArea: false,
        bottomSheetBackgroundColor: AppTheme.cream,
        dialogBackgroundColor: AppTheme.cream,
        dialogBarrierColor: Colors.black26,
        bottomSheetBuilder: (context) {
          return DraggableScrollableSheet(
            maxChildSize: 0.9,
            initialChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SessionChatPanel(
                scrollController: scrollController,
                showDragHandle: true,
              );
            },
          );
        },
        largeScreenBuilder: (_) => const SizedBox.shrink(),
      );
    case ViewportKind.mediumSmall:
    case ViewportKind.mediumPlus:
      // Overlay drawer on the room navigator so it sits above the circle,
      // not the app shell, and dismisses with the room back gesture.
      return showSessionSidePanelDrawer(
        context,
        settings: const RouteSettings(name: sessionChatRouteName),
        child: const SessionChatPanel(),
      );
  }
}
