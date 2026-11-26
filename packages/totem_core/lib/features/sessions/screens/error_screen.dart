import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

class SessionErrorScreen extends ConsumerWidget {
  const SessionErrorScreen({this.onRetry, this.error, this.session, super.key});

  final AsyncCallback? onRetry;
  final Object? error;

  /// The session detail, when available. Forwarded to
  /// [SessionDisconnectedScreen] so the post-session feedback bar can be shown
  /// (it requires a session slug to submit feedback).
  final SessionDetailSchema? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API failures arrive wrapped: the structured body lives in ApiError.error.
    var resolvedError = error;
    if (resolvedError is ApiError && resolvedError.error is RoomErrorResponse) {
      resolvedError = resolvedError.error as RoomErrorResponse;
    }

    // On web, redirect to the website when the session doesn't exist (404)
    // instead of showing the disconnected session screen.
    if (kIsWeb) {
      if (resolvedError is RoomErrorResponse &&
          resolvedError.code == ErrorCode.notFound) {
        TotemRouter.instance.toHome();
        return const SizedBox.shrink();
      }
    }

    if (resolvedError is RoomErrorResponse) {
      switch (resolvedError.code) {
        case ErrorCode.banned:
          return RoomBackground(
            status: RoomStatus.ended,
            child: SessionDisconnectedScreen(
              session: session,
              sessionDisconnectedReason: SessionDisconnectedReason.banned,
            ),
          );
        case ErrorCode.keeperNotInRoom:
          return RoomBackground(
            status: RoomStatus.ended,
            child: SessionDisconnectedScreen(
              session: session,
              sessionDisconnectedReason: SessionDisconnectedReason.keeperAbsent,
            ),
          );
        case ErrorCode.roomAlreadyEnded:
        case ErrorCode.notJoinable:
        case ErrorCode.roomNotActive:
          return RoomBackground(
            status: RoomStatus.ended,
            child: SessionDisconnectedScreen(
              session: session,
              sessionDisconnectedReason: SessionDisconnectedReason.keeperEnded,
            ),
          );
        case ErrorCode.notInRoom:
        case ErrorCode.notFound:
        case ErrorCode.livekitError:
          return RoomBackground(
            status: RoomStatus.ended,
            child: SessionDisconnectedScreen(
              session: session,
              sessionDisconnectedReason: SessionDisconnectedReason.other,
            ),
          );
        default:
          break;
      }
    }

    final errorCategory = classifySessionError(
      resolvedError,
      isOffline: ref.watch(isOfflineProvider).value ?? false,
    );
    final isOffline = errorCategory == SessionErrorCategory.offline;
    // Retrying reuses the same refused token, so send the user back instead.
    final canRetry = errorCategory != SessionErrorCategory.accessDenied;
    final title = errorCategory.title;
    final subtitle = errorCategory.message;

    final theme = Theme.of(context);

    void pop() {
      TotemRouter.instance.popOrHome(context);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: CircleIconButton(
          margin: const EdgeInsetsDirectional.only(start: 20, top: 20),
          icon: TotemIcons.arrowBack,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: pop,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: false,
        // uses a sliver to avoid overflow in landscape
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 20,
                  children: [
                    const SizedBox.shrink(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 20,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.mauve.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsetsDirectional.all(30),
                          child: TotemIcon(
                            isOffline
                                ? TotemIcons.wifiOff
                                : TotemIcons.errorOutlined,
                            size: 48,
                            color: AppTheme.gray,
                          ),
                        ),
                        Text(
                          title,
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        Text(subtitle, textAlign: TextAlign.center),
                      ],
                    ),
                    if (onRetry != null)
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          spacing: 4,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (canRetry)
                              ConfirmationDialogButton.elevated(
                                onConfirm: () async => await onRetry?.call(),
                                disabled: onRetry == null,
                                child: const Text('Try Joining Again'),
                              ),
                            InkWell(
                              onTap: pop,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                  child: Center(
                                    child: Text(
                                      'Go back to session details',
                                      style: theme.textTheme.titleSmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
