import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';

class SessionErrorScreen extends StatelessWidget {
  const SessionErrorScreen({this.onRetry, this.error, super.key});

  final VoidCallback? onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    const title = 'Something went wrong';
    const subtitle =
        "We couldn't connect you to this session. "
        'Please check your internet connection or try again.';
    const canRetry = true;

    // API failures arrive wrapped: the structured body lives in ApiError.error.
    var error = this.error;
    if (error is ApiError && error.error is RoomErrorResponse) {
      error = error.error as RoomErrorResponse;
    }

    if (error is RoomErrorResponse) {
      switch (error.code) {
        case ErrorCode.banned:
          return const SessionDisconnectedScreen(
            sessionDisconnectedReason: SessionDisconnectedReason.banned,
          );
        case ErrorCode.keeperNotInRoom:
          return const SessionDisconnectedScreen(
            sessionDisconnectedReason: SessionDisconnectedReason.keeperAbsent,
          );
        case ErrorCode.roomAlreadyEnded:
        case ErrorCode.roomNotActive:
          return const SessionDisconnectedScreen(
            sessionDisconnectedReason: SessionDisconnectedReason.keeperEnded,
          );
        case ErrorCode.notJoinable:
        case ErrorCode.notInRoom:
        case ErrorCode.notFound:
        case ErrorCode.livekitError:
          return const SessionDisconnectedScreen(
            sessionDisconnectedReason: SessionDisconnectedReason.other,
          );
        default:
          break;
      }
    }
    final theme = Theme.of(context);
    return Scaffold(
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
          onPressed: () => TotemRouter.instance.popOrHome(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              const Spacer(),
              TotemIcon(
                TotemIcons.errorOutlined,
                size: 100,
                color: theme.textTheme.headlineMedium?.color,
              ),
              Text(
                title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const Text(subtitle, textAlign: TextAlign.center),
              const Spacer(),
              if (canRetry && onRetry != null)
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 50),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
