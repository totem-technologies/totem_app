import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  const SessionErrorScreen({
    this.onRetry,
    this.error,
    this.session,
    super.key,
  });

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
          return SessionDisconnectedScreen(
            session: session,
            sessionDisconnectedReason: SessionDisconnectedReason.banned,
          );
        case ErrorCode.keeperNotInRoom:
          return SessionDisconnectedScreen(
            session: session,
            sessionDisconnectedReason: SessionDisconnectedReason.keeperAbsent,
          );
        case ErrorCode.roomAlreadyEnded:
        case ErrorCode.notJoinable:
        case ErrorCode.roomNotActive:
          return SessionDisconnectedScreen(
            session: session,
            sessionDisconnectedReason: SessionDisconnectedReason.keeperEnded,
          );
        case ErrorCode.notInRoom:
        case ErrorCode.notFound:
        case ErrorCode.livekitError:
          return SessionDisconnectedScreen(
            session: session,
            sessionDisconnectedReason: SessionDisconnectedReason.other,
          );
        default:
          break;
      }
    }

    final connectivity = ref.watch(connectivityStreamProvider);
    final initialIsOffline = ref.watch(isOfflineProvider);
    final isOfflineFromProvider = connectivity.hasValue
        ? connectivity.value!.isEmpty ||
              connectivity.value!.contains(ConnectivityResult.none)
        : initialIsOffline.value ?? false;
    final isOfflineFromError =
        resolvedError is RoomDisconnectionError &&
        isInternetDisconnectReason(resolvedError.reason);
    final isOffline = isOfflineFromProvider || isOfflineFromError;
    final title = isOffline ? "You're Offline" : 'Something went wrong';
    final subtitle = isOffline
        ? 'Video sessions require an active internet connection.\n'
              'Check your Wi-Fi or mobile data, then tap below to rejoin.'
        : "We couldn't connect you to this session. "
              'Please check your internet connection or try again.';
    const canRetry = true;

    final theme = Theme.of(context);

    void pop() {
      TotemRouter.instance.popOrHome(context);
    }

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
              onPressed: pop,
            ),
          ),
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
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
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0x1F987AA5),
                            ),
                            padding: const EdgeInsetsDirectional.all(30),
                            child: TotemIcon(
                              isOffline
                                  ? TotemIcons.wifiOff
                                  : TotemIcons.errorOutlined,
                              size: 48,
                              color: AppTheme.grey,
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
                      if (canRetry && onRetry != null)
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            spacing: 4,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConfirmationDialogButton.elevated(
                                onConfirm: () async => onRetry?.call(),
                                disabled: onRetry == null,
                                child: const Text('Try Joining Again'),
                              ),
                              InkWell(
                                onTap: pop,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                        horizontal: 20.0,
                                        vertical: 8,
                                      ),
                                  child: Text(
                                    'Go back to Session Details',
                                    style: theme.textTheme.bodySmall,
                                    textAlign: TextAlign.center,
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
      ),
    );
  }
}
