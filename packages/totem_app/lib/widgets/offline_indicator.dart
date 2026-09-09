import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/shared/totem_icons.dart';

enum ConnectivityStatus { offline, online, recentlyReconnected }

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final ConnectivityStatus status;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 10,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: switch (status) {
          ConnectivityStatus.offline => AppTheme.errorColor,
          ConnectivityStatus.online ||
          ConnectivityStatus.recentlyReconnected => AppTheme.successColor,
        },
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        spacing: 20,
        children: [
          TotemIcon(
            switch (status) {
              ConnectivityStatus.offline => TotemIcons.wifiOff,
              ConnectivityStatus.online ||
              ConnectivityStatus.recentlyReconnected => TotemIcons.wifi,
            },
            color: Colors.white,
            size: 20,
          ),
          Expanded(
            child: Text(
              switch (status) {
                ConnectivityStatus.offline => "You're Offline",
                ConnectivityStatus.online ||
                ConnectivityStatus.recentlyReconnected => "You're back online",
              },
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfflineIndicatorPage extends ConsumerStatefulWidget {
  const OfflineIndicatorPage({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineIndicatorPage> createState() =>
      _OfflineIndicatorPageState();
}

class _OfflineIndicatorPageState extends ConsumerState<OfflineIndicatorPage> {
  ConnectivityStatus _status = ConnectivityStatus.online;
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(isOfflineProvider, (_, next) {
      final isOffline = next.value;
      if (isOffline != null) _updateConnectivityStatus(isOffline);
    }, fireImmediately: true);
  }

  void _updateConnectivityStatus(bool isOffline) {
    if (isOffline) {
      _reconnectedTimer?.cancel();
      _reconnectedTimer = null;
      if (_status != ConnectivityStatus.offline) {
        setState(() => _status = ConnectivityStatus.offline);
      }
      return;
    }

    if (_status != ConnectivityStatus.offline) return;

    _resyncData();
    setState(() => _status = ConnectivityStatus.recentlyReconnected);
    _reconnectedTimer = Timer(const Duration(seconds: 3), () {
      _reconnectedTimer = null;
      if (mounted && _status == ConnectivityStatus.recentlyReconnected) {
        setState(() => _status = ConnectivityStatus.online);
      }
    });
  }

  void _resyncData() {
    if (!ref.read(listSpacesProvider).hasValue) {
      ref.invalidate(listSpacesProvider);
    }
    if (!ref.read(spacesSummaryProvider).hasValue) {
      ref.invalidate(spacesSummaryProvider);
    }
    if (!ref.read(listBlogPostsProvider).hasValue) {
      ref.invalidate(listBlogPostsProvider);
    }
    if (!ref.read(listSubscribedSpacesProvider).hasValue) {
      ref.invalidate(listSubscribedSpacesProvider);
    }
    if (!ref.read(listSessionsHistoryProvider).hasValue) {
      ref.invalidate(listSessionsHistoryProvider);
    }
  }

  @override
  void dispose() {
    _reconnectedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShow = _status != ConnectivityStatus.online;

    return SafeArea(
      top: true,
      left: false,
      right: false,
      bottom: false,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: shouldShow
                ? _StatusBanner(status: _status)
                : const SizedBox.shrink(key: ValueKey('online')),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
