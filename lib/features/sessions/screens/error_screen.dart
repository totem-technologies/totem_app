import 'package:flutter/material.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';

class RoomErrorScreen extends StatelessWidget {
  const RoomErrorScreen({this.onRetry, this.error, super.key});

  final VoidCallback? onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    var title = 'Something went wrong';
    var subtitle =
        'We couldn’t connect you to this space. '
        'Please check your internet connection or try again.';

    if (error is ErrorResponse) {
      final code = ErrorCode.fromJson((error! as ErrorResponse).error);
      switch (code) {
        case ErrorCode.banned:
          title = 'You have been banned from this space.';
          subtitle =
              'You can still join other spaces, but you won’t be able to access this one.';
        case ErrorCode.roomAlreadyEnded:
          title = 'This space has ended';
          subtitle =
              'This space has already ended. You can still join other spaces.';
        case ErrorCode.notJoinable:
          title = 'This space is not joinable';
          subtitle =
              'This space is not joinable. Please check if the link is correct or try again later.';
        default:
          break;
      }
    }
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: Container(
                margin: const EdgeInsetsDirectional.only(start: 20),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.adaptive.arrow_back,
                      color: Colors.black,
                    ),
                    iconSize: 24,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => toHome(HomeRoutes.initialRoute),
                  ),
                ),
              ),
            ),
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
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (onRetry != null)
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
    );
  }
}
