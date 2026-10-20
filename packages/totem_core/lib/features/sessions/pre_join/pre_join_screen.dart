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
            content: 'You are already in this session on another device. Do you want to leave the other session and join on this device?',
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
  const new({required this.sessionSlug, this.now = DateTime.now, super.key});

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

  Widget _entryCard(SessionDetailSchema session, PreJoinFlowState flow) {
    final nextSessions = session.space.nextEvents.where(
      (event) =>
          !event.cancelled &&
          event.slug != session.slug &&
          event.start.isAfter(widget.now()),
    );
    final nextSession = nextSessions.isEmpty ? null : nextSessions.first;
    final pending = flow.phase == PreJoinFlowPhase.pending;
    final expiration = flow.expiresAt;
    final terminal = isTerminalSessionJoinError(flow.error);
    final unavailable =
        terminal ||
        flow.admissionStatus == AdmissionStatus.denied ||
        flow.admissionStatus == AdmissionStatus.expired ||
        flow.admissionStatus == AdmissionStatus.ended;
    final early = widget.now().isBefore(
      session.start.subtract(const Duration(minutes: 10)),
    );
    final schedule = DateFormat('EEEE, MMMM d • h:mm a')
        .format(session.start.toLocal());
    final joinTime = DateFormat('h:mm a')
        .format(session.start.toLocal().subtract(const Duration(minutes: 10)));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.space.title,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                session.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '$schedule · ${session.space.author.name.value ?? 'Keeper'}',
              ),
              const SizedBox(height: 16),
              Text(
                unavailable
                    ? terminal
                          ? 'This Session is no longer available for joining.'
                          : flow.admissionStatus == AdmissionStatus.ended
                          ? 'This Session has ended.'
                          : flow.admissionStatus == AdmissionStatus.expired
                          ? 'Your admission request expired.'
                          : 'The Keeper could not admit you to this Session.'
                    : pending
                    ? session.started || widget.now().isAfter(session.start)
                          ? 'This Session may be in progress. Waiting for the Keeper to admit you.'
                          : 'Waiting for the Keeper to admit you. Your camera and microphone are only a local preview.'
                    : early
                    ? 'You can join at $joinTime.'
                    : 'Check your camera and microphone before joining.',
              ),
              if (pending && expiration != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Request expires at ${DateFormat('h:mm a').format(expiration.toLocal())}',
                ),
              ],
              if (flow.error != null && !terminal) ...[
                const SizedBox(height: 8),
                Text(
                  'Could not join the Session: ${flow.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (unavailable && nextSession != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Next Session: ${nextSession.title ?? session.space.title}',
                ),
                Text(
                  DateFormat('EEEE, MMMM d • h:mm a')
                      .format(nextSession.start.toLocal()),
                ),
                TextButton(
                  onPressed: () => context.go(
                    RouteNames.spaceSession(
                      session.space.slug,
                      nextSession.slug,
                    ),
                  ),
                  child: const Text('View next Session'),
                ),
              ],
              const SizedBox(height: 16),
              if (pending)
                OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(
                          preJoinFlowControllerProvider(widget.sessionSlug)
                              .notifier,
                        )
                        .cancelAdmission();
                    if (mounted) _backToSpace(session);
                  },
                  child: const Text('Leave waiting room'),
                )
              else if (unavailable)
                TextButton(
                  onPressed: () => _backToSpace(session),
                  child: const Text('Back to Space'),
                )
              else
                FilledButton(
                  onPressed: early || flow.phase != PreJoinFlowPhase.idle
                      ? null
                      : () => unawaited(_requestJoin()),
                  child: const Text('Join Session'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarlyEntry(SessionDetailSchema session, PreJoinFlowState flow) {
    return RoomBackground(
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => TotemRouter.instance.popOrHome(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Center(
            child: SingleChildScrollView(child: _entryCard(session, flow)),
          ),
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
    return PreJoinView(
      key: _preJoinViewKey,
      mediaState: media,
      locked:
          (flow.phase != PreJoinFlowPhase.idle &&
              flow.phase != PreJoinFlowPhase.pending) ||
          !media.initializationComplete,
      onToggleCamera: mediaController.toggleCamera,
      onToggleMicrophone: mediaController.toggleMicrophone,
      onToggleSpeaker: mediaController.toggleSpeaker,
      onCameraFacingChanged: mediaController.setCameraFacing,
      onCameraDeviceSelected: mediaController.selectCameraDevice,
      joinCard:
          flow.phase == PreJoinFlowPhase.pending ||
              flow.admissionStatus == AdmissionStatus.denied ||
              flow.admissionStatus == AdmissionStatus.expired ||
              flow.admissionStatus == AdmissionStatus.ended ||
              flow.error != null
          ? _entryCard(session, flow)
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
    if (isTerminalSessionJoinError(flow.error) ||
        flow.admissionStatus == AdmissionStatus.denied ||
        flow.admissionStatus == AdmissionStatus.expired ||
        flow.admissionStatus == AdmissionStatus.ended ||
        (!isKeeper &&
            flow.phase == PreJoinFlowPhase.idle &&
            widget.now().isBefore(
              session.start.subtract(const Duration(minutes: 10)),
            ))) {
      return _buildEarlyEntry(session, flow);
    }
    final media = ref.watch(preJoinMediaControllerProvider(widget.sessionSlug));
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
