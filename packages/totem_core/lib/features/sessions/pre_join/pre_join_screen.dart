import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_view.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/permissions_popups.dart';
import 'package:totem_core/features/sessions/widgets/session_browsing_view.dart';
import 'package:totem_core/features/sessions/widgets/session_declined_view.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_info_card.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_notice.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_view.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<bool> showAlreadyPresentDialog(BuildContext context) async {
  try {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ConfirmationDialog(
            title: "You're already in this session",
            content:
                'You are already in this session on another device. Do you want to leave the other session and join on this device?',
            icon: TotemIcons.questionMarkCircle,
            iconSize: 60,
            confirmButtonText: 'Join Here',
            onConfirm: () async => Navigator.of(context).pop(true),
            type: ConfirmationDialogType.standard,
          ),
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({
    required this.sessionSlug,
    this.now = DateTime.now,
    super.key,
  });

  final String sessionSlug;
  final ValueGetter<DateTime> now;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen>
    with WidgetsBindingObserver {
  final GlobalKey _preJoinViewKey = GlobalKey();
  bool _showingAlreadyPresentDialog = false;
  bool _showingWebPermissionsDialog = false;
  bool _reportedFullyDisplayed = false;
  bool _joined = false;
  bool _wakeLockEnabled = false;
  bool _wakeLockRequested = false;
  Future<void> _wakeLockOperation = Future.value();
  PreJoinMediaController? _mediaController;
  bool _terminalMediaReleaseRequested = false;
  Timer? _joinWindowTimer;
  DateTime? _joinWindowStart;
  bool _earlyNoticeDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setWakeLock(enabled: true));
    _initializeNativePermissions();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _joinWindowTimer?.cancel();
    if (!_joined) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    unawaited(_setWakeLock(enabled: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_setWakeLock(enabled: true));
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_setWakeLock(enabled: false));
    }
  }

  Future<void> _setWakeLock({required bool enabled}) {
    if (_wakeLockRequested == enabled && _wakeLockEnabled == enabled) {
      return _wakeLockOperation;
    }
    _wakeLockRequested = enabled;
    return _wakeLockOperation = _wakeLockOperation.then(
      (_) => _applyWakeLock(enabled: enabled),
    );
  }

  Future<void> _applyWakeLock({required bool enabled}) async {
    if (_wakeLockEnabled == enabled) return;
    if (enabled &&
        kIsWeb &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      _wakeLockEnabled = enabled;
    } catch (error, stackTrace) {
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update pre-join wake lock',
        disposition: ErrorDisposition.recovered,
        diagnostics: {'feature': 'pre_join', 'wake_lock_enabled': enabled},
      );
    }
  }

  void _initializeNativePermissions() {
    if (kIsWeb || kIsWasm) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final granted = await showPermissionsRequestSheet(context);
      if (!mounted) return;
      if (!granted) {
        if (context.canPop()) context.pop();
        return;
      }

      ref
          .read(preJoinFlowControllerProvider(widget.sessionSlug).notifier)
          .setNativePermissionsGranted(true);
      if (Platform.isAndroid && mounted) {
        await showBackgroundActivityDialog(context);
      }
      if (mounted) _reportFullyDisplayed();
    });
  }

  void _reportFullyDisplayed() {
    if (_reportedFullyDisplayed || !mounted) return;
    _reportedFullyDisplayed = true;
    SentryDisplayWidget.of(context).reportFullyDisplayed();
  }

  void _handleWebMediaState(PreJoinMediaState media) {
    if (!(kIsWeb || kIsWasm) || !media.initializationComplete || !mounted) {
      return;
    }
    if (media.canJoinOnWeb) {
      _reportFullyDisplayed();
      return;
    }
    if (_showingWebPermissionsDialog) return;
    _showingWebPermissionsDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showWebPermissionsDialog());
    });
  }

  Future<void> _showWebPermissionsDialog() async {
    if (!mounted) {
      _showingWebPermissionsDialog = false;
      return;
    }
    var granted = false;
    try {
      granted = await showWebPermissionsDeniedDialog(
        context,
        retryPermissions: () async {
          final media = await ref
              .read(preJoinMediaControllerProvider(widget.sessionSlug).notifier)
              .retryFailedMedia();
          return media.canJoinOnWeb;
        },
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to show or retry the web permissions dialog',
      );
    } finally {
      _showingWebPermissionsDialog = false;
    }
    if (granted && mounted) _reportFullyDisplayed();
  }

  Future<bool> _requestJoin({bool replaceExistingSession = false}) async {
    final outcome = await ref
        .read(preJoinFlowControllerProvider(widget.sessionSlug).notifier)
        .requestJoin(replaceExistingSession: replaceExistingSession);
    if (!mounted) return false;
    if (outcome == PreJoinJoinOutcome.confirmationRequired) {
      await _promptAlreadyPresent();
    } else if (outcome == PreJoinJoinOutcome.permissionsDenied) {
      _handleWebMediaState(
        ref.read(preJoinMediaControllerProvider(widget.sessionSlug)),
      );
    }
    return ref.read(preJoinFlowControllerProvider(widget.sessionSlug)).phase ==
        PreJoinFlowPhase.joined;
  }

  Future<void> _promptAlreadyPresent() async {
    if (_showingAlreadyPresentDialog || !mounted) return;
    _showingAlreadyPresentDialog = true;
    final join = await showAlreadyPresentDialog(context);
    _showingAlreadyPresentDialog = false;
    if (!mounted) return;
    if (join) {
      await _requestJoin(replaceExistingSession: true);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _onRetry() async {
    final _ = await ref.refresh(sessionProvider(widget.sessionSlug).future);
  }

  void _scheduleJoinWindow(SessionDetailSchema session) {
    final start = session.start.toLocal().subtract(const Duration(minutes: 10));
    if (_joinWindowStart == start) return;
    _joinWindowStart = start;
    _joinWindowTimer?.cancel();
    final remaining = start.difference(widget.now());
    if (remaining > Duration.zero) {
      _joinWindowTimer = Timer(remaining, () {
        if (mounted) setState(() {});
      });
    }
  }

  void _backToSpace(SessionDetailSchema session) {
    context.go(RouteNames.space(session.space.slug));
  }

  Widget _buildBrowsing(
    SessionDetailSchema session,
    PreJoinFlowState flow, {
    required bool early,
  }) {
    final starts = session.start.toLocal();
    final keeper = session.space.author;
    final next = session.space.nextEvents.where(
      (event) =>
          !event.cancelled &&
          event.slug != session.slug &&
          event.start.isAfter(widget.now()),
    );
    final nextSession = next.isEmpty ? null : next.first;
    final keeperImage = keeper.profileImage.value;
    final image = session.space.imageLink;
    final notice = early && !_earlyNoticeDismissed;
    return Material(
      child: Stack(
        children: [
          Positioned.fill(
            child: SessionBrowsingView(
              spaceName: session.space.title,
              sessionName: session.title,
              keeperName: keeper.name.value ?? 'Keeper',
              dateLabel: DateFormat('EEEE, MMMM d').format(starts),
              timeLabel: DateFormat('h:mm a').format(starts),
              facts: [
                SessionEntryFact(
                  icon: const Icon(Icons.timer_outlined, size: 16),
                  value: '${session.duration}',
                  label: 'minutes',
                ),
                SessionEntryFact(
                  icon: const Icon(Icons.people_outline, size: 16),
                  value: '${session.seatsLeft}',
                  label: 'seats left',
                ),
              ],
              heroPhoto: image == null || image.isEmpty
                  ? null
                  : NetworkImage(image),
              keeperPhoto: keeperImage == null || keeperImage.isEmpty
                  ? null
                  : NetworkImage(keeperImage),
              about: session.content.isEmpty ? null : session.content,
              similarSession: nextSession == null
                  ? null
                  : Text(
                      '${nextSession.title ?? session.space.title} · ${DateFormat('MMM d, h:mm a').format(nextSession.start.toLocal())}',
                    ),
              onJoin: early || flow.phase != PreJoinFlowPhase.idle
                  ? null
                  : () => unawaited(_requestJoin()),
              onBack: () => _backToSpace(session),
            ),
          ),
          if (flow.error != null && !early)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      borderRadius: BorderRadius.circular(20),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SessionEntryNotice(
                          kicker: 'Unable to join',
                          title: 'Please try again',
                          onDone: () => unawaited(_requestJoin()),
                          doneLabel: 'Try again',
                          children: [Text('${flow.error}')],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (notice)
            Positioned.fill(
              child: Stack(
                children: [
                  const ModalBarrier(dismissible: false, color: Colors.black54),
                  Align(
                    alignment: MediaQuery.sizeOf(context).width >= 640
                        ? Alignment.center
                        : Alignment.bottomCenter,
                    child: SafeArea(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: SessionEntryNotice(
                              kicker: 'A little early',
                              title: 'Your Session is coming up',
                              onDone: () =>
                                  setState(() => _earlyNoticeDismissed = true),
                              children: [
                                Text(
                                  'Join Session opens at ${DateFormat('h:mm a').format(starts.subtract(const Duration(minutes: 10)))}.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeclined(SessionDetailSchema session, PreJoinFlowState flow) {
    final next = session.space.nextEvents.where(
      (event) =>
          !event.cancelled &&
          event.slug != session.slug &&
          event.start.isAfter(widget.now()),
    );
    final offer = next.isEmpty ? null : next.first;
    final message = isTerminalSessionJoinError(flow.error)
        ? 'The server is no longer allowing this Session to be joined.'
        : switch (flow.admissionStatus) {
            AdmissionStatus.denied => 'The Keeper was unable to admit you.',
            AdmissionStatus.ended => 'The Session has ended.',
            _ => 'Your admission request has expired.',
          };
    return Material(
      color: const Color(0xFFFCEFE4),
      child: SafeArea(
        child: SessionDeclinedView(
          message: message,
          actionLabel: 'View Session',
          offer: offer == null
              ? null
              : Text(
                  '${offer.title ?? session.space.title} · ${DateFormat('EEEE, MMMM d · h:mm a').format(offer.start.toLocal())}',
                ),
          onOffer: offer == null
              ? null
              : () => context.go(
                  RouteNames.spaceSession(session.space.slug, offer.slug),
                ),
          onSignUp: offer == null
              ? null
              : () => context.go(
                  RouteNames.spaceSession(session.space.slug, offer.slug),
                ),
          onBackToSpace: () => _backToSpace(session),
        ),
      ),
    );
  }

  void _releaseTerminalPreviewMedia() {
    final mediaController = _mediaController;
    if (mediaController == null || _terminalMediaReleaseRequested) return;
    _terminalMediaReleaseRequested = true;
    unawaited(mediaController.releaseForTerminalOutcome());
  }

  Widget _buildEligibilityLoading() {
    const media = PreJoinMediaState(
      preferences: PreJoinMediaPreferences(isCameraOn: false, isMicOn: false),
      camera: PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
      microphone: PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
    );
    return PreJoinView(
      key: _preJoinViewKey,
      mediaState: media,
      locked: true,
      onToggleCamera: Future<void>.value,
      onToggleMicrophone: Future<void>.value,
      onToggleSpeaker: () {},
      onCameraFacingChanged: (_) {},
      onCameraDeviceSelected: (_) {},
      joinCard: JoinTransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        onActionPressed: () => Future.value(false),
        enabled: false,
      ),
    );
  }

  Widget _buildEndedScreen(SessionDetailSchema session) {
    _releaseTerminalPreviewMedia();
    return RoomBackground(
      status: RoomStatus.ended,
      child: SessionDisconnectedScreen(
        session: session,
        sessionDisconnectedReason: SessionDisconnectedReason.keeperEnded,
      ),
    );
  }

  Widget _buildErrorScreen(Object? error, {SessionDetailSchema? session}) {
    return RoomBackground(
      child: SessionErrorScreen(
        error: error,
        session: session,
        onRetry: _onRetry,
      ),
    );
  }

  Widget _buildPreJoinView(
    PreJoinMediaState media,
    PreJoinFlowState flow,
    SessionDetailSchema session,
  ) {
    final mediaController = ref.read(
      preJoinMediaControllerProvider(widget.sessionSlug).notifier,
    );
    _mediaController = mediaController;
    final permissionsGranted = (kIsWeb || kIsWasm)
        ? media.canJoinOnWeb
        : flow.nativePermissionsGranted;
    final pending = flow.phase == PreJoinFlowPhase.pending;
    void leaveWaiting() {
      unawaited(() async {
        await ref
            .read(preJoinFlowControllerProvider(widget.sessionSlug).notifier)
            .cancelAdmission();
        if (mounted) _backToSpace(session);
      }());
    }

    return PreJoinView(
      key: _preJoinViewKey,
      mediaState: media,
      waiting: pending,
      onLeave: pending ? leaveWaiting : null,
      locked:
          (flow.phase != PreJoinFlowPhase.idle &&
              flow.phase != PreJoinFlowPhase.pending) ||
          !media.initializationComplete,
      onToggleCamera: mediaController.toggleCamera,
      onToggleMicrophone: mediaController.toggleMicrophone,
      onToggleSpeaker: mediaController.toggleSpeaker,
      onCameraFacingChanged: mediaController.setCameraFacing,
      onCameraDeviceSelected: mediaController.selectCameraDevice,
      joinCard: pending
          ? SessionWaitingCard(
              title: 'Waiting to join',
              body: Text(
                'The Keeper will let you in. Your camera and microphone are only a local preview.\n'
                'Request expires at ${flow.expiresAt == null ? 'soon' : DateFormat('h:mm a').format(flow.expiresAt!.toLocal())}.',
              ),
              actionLabel: 'Leave waiting room',
              onAction: leaveWaiting,
            )
          : JoinTransitionCard(
              margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
              keepActionLoadingOnSuccess: true,
              enabled: permissionsGranted,
              onActionPressed: _requestJoin,
              isSliderLoading: flow.phase == PreJoinFlowPhase.joining,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionData = ref.watch(sessionProvider(widget.sessionSlug));
    if (sessionData.hasError) {
      if (isTerminalSessionJoinError(sessionData.error)) {
        _releaseTerminalPreviewMedia();
      }
      return _buildErrorScreen(sessionData.error);
    }

    final loadingData = sessionData.isLoading && !sessionData.isRefreshing;
    if (loadingData) return _buildEligibilityLoading();

    final session = sessionData.value;
    if (session?.ended ?? false) return _buildEndedScreen(session!);

    final flow = ref.watch(preJoinFlowControllerProvider(widget.sessionSlug));
    if (session == null) return _buildEligibilityLoading();
    _scheduleJoinWindow(session);
    final keeperIdentity = session.space.author.slug.value;
    final isKeeper =
        keeperIdentity != null &&
        keeperIdentity == ref.watch(authControllerProvider).user?.slug.value;
    final early =
        !isKeeper &&
        widget.now().isBefore(
          session.start.subtract(const Duration(minutes: 10)),
        );
    if (isTerminalSessionJoinError(flow.error) ||
        flow.admissionStatus == AdmissionStatus.denied ||
        flow.admissionStatus == AdmissionStatus.expired ||
        flow.admissionStatus == AdmissionStatus.ended) {
      return _buildDeclined(session, flow);
    }
    if (early && flow.phase == PreJoinFlowPhase.idle) {
      return _buildBrowsing(session, flow, early: true);
    }
    final media = ref.watch(preJoinMediaControllerProvider(widget.sessionSlug));
    if (flow.phase == PreJoinFlowPhase.idle) {
      return _buildBrowsing(session, flow, early: false);
    }
    _joined = flow.phase == PreJoinFlowPhase.joined;

    ref.listen(preJoinMediaControllerProvider(widget.sessionSlug), (_, next) {
      _handleWebMediaState(next);
    });

    final preJoinView = _buildPreJoinView(media, flow, session);
    final hasStartedJoin =
        flow.phase != PreJoinFlowPhase.idle && flow.sessionOptions != null;
    if (!hasStartedJoin || loadingData) {
      return preJoinView;
    }

    return ProviderScope(
      overrides: [
        sessionScopeProvider.overrideWith((_) => flow.sessionOptions!),
      ],
      child: VideoSessionScreen(
        sessionSlug: widget.sessionSlug,
        loadingScreen: preJoinView,
        showAdmissionOrientation:
            flow.admissionStatus == AdmissionStatus.approved,
      ),
    );
  }
}
