import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/admission/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/session_button_style.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Presents session-owned admission state and commands in the room layout.
class SessionAdmissionOverlay extends ConsumerStatefulWidget {
  const SessionAdmissionOverlay({
    required this.sessionSlug,
    required this.child,
    this.now,
    super.key,
  });

  final String sessionSlug;
  final Widget child;
  final DateTime Function()? now;

  @override
  ConsumerState<SessionAdmissionOverlay> createState() =>
      _SessionAdmissionOverlayState();
}

class _SessionAdmissionOverlayState
    extends ConsumerState<SessionAdmissionOverlay> {
  final _notifications = NotificationController();
  String? _lastError;
  SessionAdmissionService? _service;
  @override
  void dispose() {
    _service?.removeListener(_changed);
    _notifications.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final error = _service?.error;
    if (error != null && error != _lastError) {
      if (error == 'Admission in progress' ||
          error == 'New participants arrived') {
        _notifications.showTimed(
          context,
          icon: TotemIcons.info,
          title: error,
          message: error == 'Admission in progress'
              ? 'Wait for the current admission decision to finish, then try again.'
              : 'Review the waiting room and try again before starting.',
        );
      } else {
        _notifications.showError(
          context,
          icon: TotemIcons.errorOutlined,
          title: error,
          message: 'Please check your connection and try again.',
        );
      }
    }
    _lastError = error;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final candidate = ref.watch(currentSessionProvider)?.admission;
    final service = candidate?.mounted == true ? candidate : null;
    if (!identical(service, _service)) {
      _service?.removeListener(_changed);
      _service = service;
      service?.addListener(_changed);
    }
    VoidCallback? retry;
    Future<void> Function()? resetCorruptData;
    final keeper = ref.watch(keeperIdentityProvider);
    if (keeper != null &&
        ref.read(currentSessionProvider)?.room?.localParticipant?.identity ==
            keeper) {
      final provider = declinedSessionParticipantsProvider(
        widget.sessionSlug,
        keeper,
      );
      final rosterProvider = keeperAdmissionRosterProvider(
        widget.sessionSlug,
        keeper,
      );
      final declined = ref.watch(provider);
      final roster = ref.watch(rosterProvider);
      if ((declined.hasError && !declined.hasValue) ||
          (roster.hasError && !roster.hasValue)) {
        retry = () {
          if (declined.hasError) ref.invalidate(provider);
          if (roster.hasError) ref.invalidate(rosterProvider);
        };
        final corruptDeclined =
            declined.error is CorruptSessionAdmissionData && !declined.hasValue;
        final corruptRoster =
            roster.error is CorruptSessionAdmissionData && !roster.hasValue;
        if (corruptDeclined || corruptRoster) {
          resetCorruptData = () async {
            if (corruptDeclined) {
              await ref.read(provider.notifier).resetCorruptData();
            }
            if (corruptRoster) {
              await ref.read(rosterProvider.notifier).resetCorruptData();
            }
          };
        }
      }
    }
    if (service?.recoveryError != null) {
      retry ??= () => unawaited(
        service!.retryRecovery().catchError((Object error, StackTrace stack) {
          ErrorHandler.logError(
            error,
            stackTrace: stack,
            message: 'Admission recovery retry failed',
          );
          if (context.mounted) {
            _notifications.showError(
              context,
              icon: TotemIcons.errorOutlined,
              title: 'Admission recovery is still pending',
              message:
                  'Keep this session open and retry admission recovery. No removal request was sent.',
            );
          }
        }),
      );
    }
    final corruptRemovalJournal = service?.hasCorruptRemovalJournal ?? false;
    final controller = service?.keeperController;
    final attempts =
        controller?.attempts
            .where(
              (attempt) => !controller.isPermanentlyDeclined(
                attempt.request.senderIdentity,
              ),
            )
            .toList() ??
        const <KeeperAdmissionAttempt>[];
    final requests = controller?.requests ?? const <AdmissionRequest>[];
    return SessionAdmissionScope(
      recoveryMessage: service?.recoveryError,
      unresolvedRemovals: service?.unresolvedRemovals ?? const {},
      corruptRemovalJournal: corruptRemovalJournal,
      onResetCorruptRemovalJournal: corruptRemovalJournal
          ? service!.resetCorruptRemovalJournal
          : null,
      onReconcileRemoval: (identity, removed) async {
        await service?.reconcileRemoval(identity, backendRemoved: removed);
      },
      requests: requests,
      attempts: attempts,
      enabled: controller?.approvalRequired ?? false,
      busy: service?.busy ?? false,
      onRetry: retry,
      onResetCorruptData: resetCorruptData,
      onDecision: (request, approve) async {
        await service?.decide(request, approve);
      },
      onDeclinePermanently: (request) =>
          service?.decide(request, false, permanently: true) ?? Future.value(),
      onAdmitAll: () async => await service?.admitAll() ?? false,
      child: widget.child,
    );
  }
}

const sessionAdmissionRouteName = 'session-admission';

/// A queue control in normal Session layout; it never positions itself over video.
class SessionAdmissionQueueControl extends ConsumerWidget {
  const SessionAdmissionQueueControl({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admission = SessionAdmissionScope.maybeOf(context);
    if (admission == null) return child ?? const SizedBox.shrink();
    final joining = admission.attempts.any(
      (attempt) => attempt.status == KeeperAdmissionStatus.joining,
    );
    final retry = admission.onRetry;
    if (retry == null &&
        (!admission.enabled || (admission.requests.isEmpty && !joining))) {
      return child ?? const SizedBox.shrink();
    }
    String? label;
    if (retry != null) {
      label = 'Admission unavailable';
    } else if (admission.requests.isEmpty) {
      label = 'Admission in progress';
    }
    final button = SessionWaitingQueueButton(
      count: admission.requests.length,
      label: label,
      onPressed: () => unawaited(_showSessionAdmission(context, ref)),
    );
    if (child == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [button, child!],
    );
  }
}

Future<void> _showSessionAdmission(BuildContext context, WidgetRef ref) async {
  ref
      .read(sessionPresentationProvider.notifier)
      .togglePanel(SessionPanel.admission);
}

Future<void> presentSessionAdmission(BuildContext context) async {
  final kind = ViewportResolver.getViewportKind(context);
  if (kind == ViewportKind.mediumSmall || kind == ViewportKind.mediumPlus) {
    await showSessionSidePanelDrawer(
      context,
      settings: const RouteSettings(name: sessionAdmissionRouteName),
      child: const SessionAdmissionPanel(),
    );
    return;
  }
  await showResponsiveModal<void>(
    context: sessionNavigatorContext(context),
    useRootNavigator: false,
    routeSettings: const RouteSettings(name: sessionAdmissionRouteName),
    showDragHandle: true,
    bottomSheetBackgroundColor: AppTheme.cream,
    dialogBackgroundColor: AppTheme.cream,
    bottomSheetBuilder: (context) => SizedBox(
      height: MediaQuery.heightOf(context) * 0.7,
      child: const SessionAdmissionPanel(),
    ),
    largeScreenBuilder: (context) => const SizedBox(
      width: sessionSidePanelWidth,
      child: SessionAdmissionPanel(),
    ),
  );
}

/// Shared live content for the desktop rail, tablet drawer, and phone sheet.
class SessionAdmissionPanel extends ConsumerWidget {
  const SessionAdmissionPanel({this.docked = false, super.key});

  final bool docked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admission = SessionAdmissionScope.maybeOf(context);
    if (admission == null) return const SizedBox.shrink();
    void close() {
      if (docked || ref.read(currentSessionProvider) != null) {
        ref
            .read(sessionPresentationProvider.notifier)
            .closePanel(expectedPanel: SessionPanel.admission);
      } else {
        Navigator.of(context).maybePop();
      }
    }

    final retry = admission.onRetry;
    final resetRemovalJournal = admission.onResetCorruptRemovalJournal;
    if (retry != null) {
      return Material(
        color: AppTheme.cream,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  admission.recoveryMessage ??
                      'Could not load admission recovery data. Please retry.',
                  style: const TextStyle(color: AppTheme.slate),
                ),
                OutlinedButton(
                  onPressed: retry,
                  style: SessionButtonStyle.outlined(),
                  child: const Text('Retry'),
                ),
                for (final identity in admission.unresolvedRemovals)
                  for (final removed in [true, false])
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: sessionNavigatorContext(context),
                        useRootNavigator: false,
                        builder: (dialogContext) => ConfirmationDialog(
                          title: 'Reconcile removal of $identity?',
                          content: removed
                              ? 'Only confirm after verifying removal succeeded. This updates admission recovery without sending another removal request.'
                              : 'Only confirm after verifying removal was rejected. This restores admission eligibility without sending another removal request.',
                          confirmButtonText: 'Confirm verified outcome',
                          type: ConfirmationDialogType.standard,
                          onConfirm: () async {
                            try {
                              await admission.onReconcileRemoval?.call(
                                identity,
                                removed,
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                await ErrorHandler.handleApiError(
                                  dialogContext,
                                  error,
                                  useRootNavigator: false,
                                );
                              }
                            }
                          },
                        ),
                      ),
                      child: Text(
                        removed
                            ? 'Verified $identity was removed'
                            : 'Verified $identity was not removed',
                      ),
                    ),
                if (admission.onResetCorruptData case final reset?)
                  OutlinedButton(
                    style: SessionButtonStyle.outlined(),
                    onPressed: () => showDialog<void>(
                      context: sessionNavigatorContext(context),
                      useRootNavigator: false,
                      builder: (dialogContext) => ConfirmationDialog(
                        title: 'Reset admission data?',
                        content:
                            'Corrupt admission data will be removed. If the roster is reset, participants must be admitted again. If declined participants are reset, permanent declines will be lost.',
                        confirmButtonText: 'Reset admission data',
                        scrollable: true,
                        onConfirm: () async {
                          try {
                            await reset();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (error, stackTrace) {
                            ErrorHandler.logError(
                              error,
                              stackTrace: stackTrace,
                              message: 'Could not reset admission data',
                            );
                            if (dialogContext.mounted) {
                              ErrorHandler.showErrorDialog(
                                sessionNavigatorContext(dialogContext),
                                useRootNavigator: false,
                                message:
                                    'Could not reset admission data. Please try again.',
                              );
                            }
                          }
                        },
                      ),
                    ),
                    child: const Text('Reset admission data'),
                  ),
                if (admission.corruptRemovalJournal &&
                    resetRemovalJournal != null)
                  OutlinedButton(
                    style: SessionButtonStyle.outlined(),
                    onPressed: () => showDialog<void>(
                      context: sessionNavigatorContext(context),
                      useRootNavigator: false,
                      builder: (dialogContext) => ConfirmationDialog(
                        title: 'Reset removal recovery?',
                        content:
                            'The removal recovery journal is unreadable, so it is not possible to tell whether a participant removal completed. Resetting recovery clears the saved admitted roster to avoid restoring stale access. Participants will need to be admitted again.',
                        confirmButtonText: 'Reset removal recovery',
                        scrollable: true,
                        onConfirm: () async {
                          try {
                            await resetRemovalJournal();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (error, stackTrace) {
                            ErrorHandler.logError(
                              error,
                              stackTrace: stackTrace,
                              message: 'Could not reset removal recovery',
                            );
                            if (dialogContext.mounted) {
                              ErrorHandler.showErrorDialog(
                                sessionNavigatorContext(dialogContext),
                                useRootNavigator: false,
                                message:
                                    'Could not reset removal recovery. Please try again.',
                              );
                            }
                          }
                        },
                      ),
                    ),
                    child: const Text('Reset removal recovery'),
                  ),
                OutlinedButton(
                  onPressed: close,
                  style: SessionButtonStyle.outlined(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppTheme.cream,
      elevation: docked ? 6 : 0,
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.16),
      child: SafeArea(
        child: KeeperAdmissionPanel(
          requests: admission.requests,
          attempts: admission.attempts,
          busy: admission.busy,
          embedded: true,
          desktop: docked,
          onDecision: admission.onDecision,
          onDeclinePermanently: admission.onDeclinePermanently,
          onAdmitAll: () => unawaited(admission.onAdmitAll()),
          onClose: close,
        ),
      ),
    );
  }
}
