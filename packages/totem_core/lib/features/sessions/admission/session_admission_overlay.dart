import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    show Participant, ParticipantStatus;
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/admission/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
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
    return SessionAdmissionScope(
      requests: service?.requests ?? const <Participant>[],
      attempts: service?.attempts ?? const <Participant>[],
      enabled: service?.approvalRequired ?? false,
      busy: service?.busy ?? false,
      onRetry: service?.snapshot == null && service != null
          ? service.sync
          : null,
      onRefresh: service?.error != null ? service?.sync : null,
      onRetryUnresolved: service?.hasUnresolvedCommand == true
          ? () async {
              await service!.retryUnresolved();
            }
          : null,
      error: service?.error,
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
    if (!ref.watch(isCurrentUserKeeperProvider)) {
      return child ?? const SizedBox.shrink();
    }
    final retry = admission.onRetry;
    final joining = admission.attempts.any(
      (attempt) => attempt.status == ParticipantStatus.approved,
    );
    if (retry == null &&
        admission.onRefresh == null &&
        admission.onRetryUnresolved == null &&
        admission.requests.isEmpty &&
        !joining) {
      return child ?? const SizedBox.shrink();
    }
    final label =
        retry != null ||
            admission.onRefresh != null ||
            admission.onRetryUnresolved != null
        ? 'Admission needs attention'
        : admission.requests.isEmpty
        ? 'Admission in progress'
        : null;
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
class SessionAdmissionPanel extends ConsumerStatefulWidget {
  const SessionAdmissionPanel({this.docked = false, super.key});

  final bool docked;

  @override
  ConsumerState<SessionAdmissionPanel> createState() =>
      _SessionAdmissionPanelState();
}

class _SessionAdmissionPanelState extends ConsumerState<SessionAdmissionPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = ref.read(currentSessionProvider)?.admission;
      if (service?.mounted == true) service!.sync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admission = SessionAdmissionScope.maybeOf(context);
    if (admission == null) return const SizedBox.shrink();
    void close() {
      if (widget.docked || ref.read(currentSessionProvider) != null) {
        ref
            .read(sessionPresentationProvider.notifier)
            .closePanel(expectedPanel: SessionPanel.admission);
      } else {
        Navigator.of(context).maybePop();
      }
    }

    final retry = admission.onRetry;
    if (retry != null) {
      return Material(
        color: AppTheme.cream,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  admission.error ??
                      'Could not load admission data. Please retry.',
                ),
                OutlinedButton(onPressed: retry, child: const Text('Retry')),
                if (admission.onRetryUnresolved case final retryCommand?)
                  OutlinedButton(
                    onPressed: admission.busy
                        ? null
                        : () => unawaited(retryCommand()),
                    child: const Text('Retry unresolved command'),
                  ),
                OutlinedButton(onPressed: close, child: const Text('Close')),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppTheme.cream,
      child: SafeArea(
        child: KeeperAdmissionPanel(
          requests: admission.requests,
          attempts: admission.attempts,
          busy: admission.busy,
          embedded: true,
          desktop: widget.docked,
          error: admission.error,
          onRefresh: admission.onRefresh,
          onRetryUnresolved: admission.onRetryUnresolved,
          onDecision: admission.onDecision,
          onDeclinePermanently: admission.onDeclinePermanently,
          onAdmitAll: () => unawaited(admission.onAdmitAll()),
          onClose: close,
        ),
      ),
    );
  }
}
