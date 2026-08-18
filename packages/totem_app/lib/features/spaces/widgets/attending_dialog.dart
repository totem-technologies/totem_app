import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:totem_core/core/api/api_client/models/session_detail_schema.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/calendar_service.dart';
import 'package:totem_core/shared/network.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confetti.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> addSessionToCalendar(
  BuildContext context,
  SessionDetailSchema session,
) async {
  final notificationController = NotificationController();
  final space = session.space;
  final calendarEvent = AppCalendarEvent(
    title: '[TOTEM] ${session.title} - ${space.title}',
    description: space.shortDescription,
    location: getFullUrl(session.calLink),
    start: session.start.toLocal(),
    end: session.start.add(Duration(minutes: session.duration)).toLocal(),
    reminderMinutesBefore: 10,
  );
  try {
    final success = await CalendarService.addToCalendar(calendarEvent);
    if (!success && context.mounted) {
      notificationController.showError(
        context,
        icon: TotemIcons.calendar,
        title: 'Failed to add event to calendar',
        message: 'Please try again later',
      );
    }
  } catch (e, st) {
    ErrorHandler.logError(
      e,
      stackTrace: st,
      message: 'Failed to add to calendar',
    );
    if (context.mounted) {
      notificationController.showError(
        context,
        icon: TotemIcons.calendar,
        title: 'Failed to add event to calendar',
        message: 'Please try again later',
      );
    }
  }
}

Future<void> showAttendingDialog(
  BuildContext context,
  SessionDetailSchema event,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AttendingDialog(
      eventSlug: event.slug,
      onAddToCalendar: () => addSessionToCalendar(context, event),
    ),
  );
  if (context.mounted) ConfettiController.showConfetti(context);
}

class AttendingDialog extends StatefulWidget {
  const AttendingDialog({
    required this.onAddToCalendar,
    required this.eventSlug,
    super.key,
  });

  final String eventSlug;
  final VoidCallback onAddToCalendar;

  @override
  State<AttendingDialog> createState() => _AttendingDialogState();
}

class _AttendingDialogState extends State<AttendingDialog> {
  var _addedToCalendar = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) {
                    return Container(
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: IconButton(
                        padding: EdgeInsetsDirectional.zero,
                        iconSize: 18,
                        color: AppTheme.gray,
                        onPressed: () async {
                          final box = context.findRenderObject() as RenderBox?;
                          await SharePlus.instance.share(
                            ShareParams(
                              uri: Uri.parse(AppConfig.instance.apiUrl)
                                  .resolve('/spaces/event/${widget.eventSlug}')
                                  .resolve('?utm_source=app&utm_medium=share'),
                              sharePositionOrigin: box != null
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : null,
                            ),
                          );
                        },
                        icon: Icon(Icons.adaptive.share),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Container(
                  height: 30,
                  width: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: IconButton(
                    padding: EdgeInsetsDirectional.zero,
                    iconSize: 18,
                    color: AppTheme.gray,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
            const TotemIcon(
              TotemIcons.greenCheckbox,
              size: 95,
              color: Color(0xFF98BD44),
            ),
            Text(
              "You're going!",
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text:
                        "We'll send you a notification before the session "
                        'starts.',
                  ),
                  TextSpan(text: '\n\n'),
                  TextSpan(
                    text:
                        'When you join, you\u2019ll be in a Space where we take '
                        'turns speaking while holding the virtual Totem \u2014 '
                        'feel free to share when it\u2019s your turn, or simply '
                        'listen if you prefer.',
                  ),
                  TextSpan(text: '\n\n'),
                  TextSpan(
                    text: 'Totem is better with friends!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        " Share this link with your friends and they'll be "
                        'able to join as well.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () {
                if (!_addedToCalendar) {
                  widget.onAddToCalendar();
                  setState(() => _addedToCalendar = true);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Text(_addedToCalendar ? 'Added!' : 'Add to Calendar'),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'In the meantime, review our '),
                  TextSpan(
                    text: 'Community Guidelines',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        AppConfig.instance.communityGuidelinesUrl,
                        mode: LaunchMode.externalApplication,
                      ),
                  ),
                  const TextSpan(
                    text: ' to learn more about how to participate.',
                  ),
                ],
              ),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
