import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/core/api/lib/totem_mobile_api.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/loading_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/download_mobile_app_dialog.dart';
import 'package:totem_core/features/sessions/widgets/permissions_popups.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Shows a dialog when the user tries to join a session they are already
/// in on another device, asking if they want to leave the other session
/// and join on this device instead.
///
/// Returns true if the user chooses to leave the other session and join
/// on this device, false otherwise.
Future<bool> showAlreadyPresentDialog(BuildContext context) async {
  try {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return ConfirmationDialog(
              title: "You're Already in This Session",
              content:
                  'You are already in this session on another device. Do you want to leave the other session and join on this device?',
              icon: TotemIcons.questionMarkCircle,
              iconSize: 60,
              confirmButtonText: 'Join Here',
              onConfirm: () async {
                Navigator.of(context).pop(true);
              },
              type: ConfirmationDialogType.standard,
            );
          },
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({
    required this.sessionSlug,
    this.previewTrackFactory,
    super.key,
  });

  final String sessionSlug;
  final PreJoinPreviewTrackFactory? previewTrackFactory;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  // Session/join lifecycle state
  SessionOptions? _sessionOptions;
  bool _hasRequestedJoin = false;
  bool get hasRequestedJoin => _hasRequestedJoin;
  bool _showingAlreadyPresentDialog = false;
  bool? _isLoading;

  MediaPreferences _mediaPreferences = const MediaPreferences();

  final GlobalKey _loadingScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializeAndCheckPermissions();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (!hasRequestedJoin) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    WakelockPlus.disable();
    super.dispose();
  }

  void _initializeAndCheckPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await showDownloadMobileAppDialog(context);
      if (!mounted) return;

      final granted = await showPermissionsRequestSheet(context);
      if (!mounted) return;

      if (!granted) {
        context.pop();
        return;
      }

      if (!kIsWeb && Platform.isAndroid) {
        if (!mounted) return;
        await showBackgroundActivityDialog(context);
      }

      if (mounted) {
        SentryDisplayWidget.of(context).reportFullyDisplayed();
      }
    });
  }

  // ===== UI =====

  Widget _buildPrejoinUI() {
    return PrejoinSessionScreen(
      key: _loadingScreenKey,
      previewTrackFactory: widget.previewTrackFactory,
      onMediaPreferencesChanged: (prefs) {
        _mediaPreferences = prefs;
      },
      joinCard: TransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        type: TotemCardTransitionType.join,
        keepActionLoadingOnSuccess: true,
        onActionPressed: () async {
          await _joinRoom();
          return _hasRequestedJoin;
        },
        isSliderLoading: _isLoading,
      ),
      locked: hasRequestedJoin,
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return RoomBackground(
      child: SessionErrorScreen(
        error: error,
        onRetry: _onRetry,
      ),
    );
  }

  // ===== Join flow =====

  Future<void> _handleToken(
    JoinResponse response, {
    bool mayShowAlreadyPresentDialog = true,
  }) async {
    final isSpeakerOn = _mediaPreferences.isSpeakerOn;
    final isCameraOn = _mediaPreferences.isCameraOn;
    final isMicOn = _mediaPreferences.isMicOn;
    final cameraOptions = _mediaPreferences.cameraOptions;

    _sessionOptions = SessionOptions(
      eventSlug: widget.sessionSlug,
      token: response.token,
      cameraEnabled: isCameraOn,
      microphoneEnabled: isMicOn,
      speakerEnabled: isSpeakerOn,
      cameraOptions: cameraOptions,
    );

    if (mounted) setState(() {});

    if (hasRequestedJoin || !mounted) return;

    final shouldShowAlreadyPresentDialog =
        mayShowAlreadyPresentDialog &&
        response.isAlreadyPresent &&
        widget.sessionSlug.isNotEmpty;

    if (shouldShowAlreadyPresentDialog && !_showingAlreadyPresentDialog) {
      _showingAlreadyPresentDialog = true;
      final join = await showAlreadyPresentDialog(context);
      _showingAlreadyPresentDialog = false;

      if (join) {
        await _joinRoom(showAlreadyPresentDialog: false);
      } else {
        if (mounted) context.pop();
      }
    }
  }

  Future<void> _joinRoom({bool showAlreadyPresentDialog = true}) async {
    try {
      final response = await ref.read(
        sessionTokenProvider(widget.sessionSlug).future,
      );
      await _handleToken(
        response,
        mayShowAlreadyPresentDialog: showAlreadyPresentDialog,
      );

      if (_sessionOptions == null ||
          hasRequestedJoin ||
          _showingAlreadyPresentDialog) {
        return;
      }

      setState(() {
        _hasRequestedJoin = true;
        _isLoading = true;
      });

      // precache event data to speed up join process and avoid showing loading screen if the
      await ref.read(eventProvider(widget.sessionSlug).future);

      final session = ref.read(
        sessionControllerProvider(_sessionOptions!).notifier,
      )..preventAutoDispose();

      await session.join();

      _isLoading = false;
    } catch (error, stackTrace) {
      _hasRequestedJoin = _isLoading = false;
      if (mounted) {
        setState(() {});
      }
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to join room',
      );
    } finally {
      if (_sessionOptions != null) {
        ref
            .read(sessionControllerProvider(_sessionOptions!).notifier)
            .allowAutoDispose();
      }
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _onRetry() async {
    setState(() => _isLoading = null);
    final _ = await ref.refresh(
      sessionTokenProvider(widget.sessionSlug).future,
    );
    final _ = await ref.refresh(eventProvider(widget.sessionSlug).future);
  }

  // ===== Provider listeners =====

  void _listenForTokenUpdates() {
    ref.listen(
      sessionTokenProvider(widget.sessionSlug),
      (previous, next) async {
        if (next case AsyncData(:final value)) {
          _handleToken(value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokenData = ref.watch(sessionTokenProvider(widget.sessionSlug));
    final sessionData = ref.watch(eventProvider(widget.sessionSlug));

    _listenForTokenUpdates();

    if (tokenData.hasError) {
      return _buildErrorScreen(tokenData.error);
    }

    if (sessionData.hasError) {
      return _buildErrorScreen(sessionData.error);
    }

    final isLoading =
        (tokenData.isLoading && !tokenData.isRefreshing) ||
        (sessionData.isLoading && !sessionData.isRefreshing);

    if (!hasRequestedJoin || isLoading) {
      return _buildPrejoinUI();
    }

    return ProviderScope(
      overrides: [
        sessionScopeProvider.overrideWith((ref) => _sessionOptions!),
      ],
      child: VideoSessionScreen(
        sessionSlug: widget.sessionSlug,
        loadingScreen: _buildPrejoinUI(),
      ),
    );
  }
}
