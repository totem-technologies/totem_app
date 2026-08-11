import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_view.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/permissions_popups.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<bool> showAlreadyPresentDialog(BuildContext context) async {
  try {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ConfirmationDialog(
            title: "You're Already in This Session",
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
  const PreJoinScreen({required this.sessionSlug, super.key});

  final String sessionSlug;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  final GlobalKey _preJoinViewKey = GlobalKey();
  bool _showingAlreadyPresentDialog = false;
  bool _showingWebPermissionsDialog = false;
  bool _reportedFullyDisplayed = false;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _initializeNativePermissions();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    if (!_joined) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _initializeNativePermissions() {
    if (kIsWeb || kIsWasm) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final granted = await showPermissionsRequestSheet(context);
      if (!mounted) return;
      if (!granted) {
        context.pop();
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
    final granted = await showWebPermissionsDeniedDialog(
      context,
      retryPermissions: () async {
        final media = await ref
            .read(
              preJoinMediaControllerProvider(widget.sessionSlug).notifier,
            )
            .retryFailedMedia();
        return media.canJoinOnWeb;
      },
    );
    _showingWebPermissionsDialog = false;
    if (granted && mounted) _reportFullyDisplayed();
  }

  Future<bool> _requestJoin({bool replaceExistingSession = false}) async {
    final outcome = await ref
        .read(preJoinFlowControllerProvider(widget.sessionSlug).notifier)
        .requestJoin(replaceExistingSession: replaceExistingSession);
    if (!mounted) return false;
    if (outcome == PreJoinJoinOutcome.confirmationRequired) {
      await _promptAlreadyPresent();
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
    final _ = await ref.refresh(
      sessionTokenProvider(widget.sessionSlug).future,
    );
    final _ = await ref.refresh(eventProvider(widget.sessionSlug).future);
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
  ) {
    final mediaController = ref.read(
      preJoinMediaControllerProvider(widget.sessionSlug).notifier,
    );
    final permissionsGranted = (kIsWeb || kIsWasm)
        ? media.canJoinOnWeb
        : flow.nativePermissionsGranted;
    return PreJoinView(
      key: _preJoinViewKey,
      mediaState: media,
      locked:
          flow.phase != PreJoinFlowPhase.idle || !media.initializationComplete,
      onToggleCamera: mediaController.toggleCamera,
      onToggleMicrophone: mediaController.toggleMicrophone,
      onToggleSpeaker: mediaController.toggleSpeaker,
      onCameraPositionChanged: mediaController.setCameraPosition,
      onCameraDeviceSelected: mediaController.selectCameraDevice,
      joinCard: JoinTransitionCard(
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
    final tokenData = ref.watch(sessionTokenProvider(widget.sessionSlug));
    final sessionData = ref.watch(eventProvider(widget.sessionSlug));
    final media = ref.watch(preJoinMediaControllerProvider(widget.sessionSlug));
    final flow = ref.watch(preJoinFlowControllerProvider(widget.sessionSlug));
    _joined = flow.phase == PreJoinFlowPhase.joined;

    ref
      ..listen(preJoinMediaControllerProvider(widget.sessionSlug), (_, next) {
        _handleWebMediaState(next);
      })
      ..listen(sessionTokenProvider(widget.sessionSlug), (_, next) {
        if (next case AsyncData(:final value)
            when value.isAlreadyPresent &&
                flow.phase == PreJoinFlowPhase.idle &&
                !_showingAlreadyPresentDialog) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_promptAlreadyPresent());
          });
        }
      });

    if (tokenData.hasError) {
      return _buildErrorScreen(tokenData.error, session: sessionData.value);
    }
    if (sessionData.hasError) return _buildErrorScreen(sessionData.error);

    final loadingData =
        (tokenData.isLoading && !tokenData.isRefreshing) ||
        (sessionData.isLoading && !sessionData.isRefreshing);
    final preJoinView = _buildPreJoinView(media, flow);
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
      ),
    );
  }
}
