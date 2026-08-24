import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/shared/logger.dart';
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
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        // vertical: 8,
      ),
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
                ConnectivityStatus.offline => 'You’re Offline',
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
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await ref.read(connectivityProvider).checkConnectivity();
    _updateConnectivityStatus(result, isInitialCheck: true);
  }

  void _updateConnectivityStatus(
    List<ConnectivityResult> result, {
    bool isInitialCheck = false,
  }) {
    final bool wasOffline = _status == ConnectivityStatus.offline;
    final bool isNowOffline =
        result.isEmpty || result.contains(ConnectivityResult.none);

    if (mounted) {
      if (isNowOffline) {
        setState(() {
          _status = ConnectivityStatus.offline;
        });
      } else {
        if (wasOffline && !isInitialCheck) {
          _resyncData();
          setState(() {
            _status = ConnectivityStatus.recentlyReconnected;
          });
          _reconnectedTimer?.cancel();
          _reconnectedTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _status = ConnectivityStatus.online;
              });
            }
          });
        } else if (_status != ConnectivityStatus.recentlyReconnected) {
          setState(() {
            _status = ConnectivityStatus.online;
          });
        }
      }
    }
  }

  void _resyncData() {
    void smartRefresh(
      //
      // ignore: strict_raw_type, invalid_use_of_internal_member
      $FunctionalProvider<AsyncValue, dynamic, dynamic> provider,
    ) {
      // Workaround for the riverpod typing inconsistency
      if (!ref.read(provider).hasValue) {
        logger.i('Refreshing $provider due to reconnection');
        ref.invalidate(provider);
      } else {
        // ref.refresh(provider);
      }
    }

    smartRefresh(listSpacesProvider);
    smartRefresh(spacesSummaryProvider);
    smartRefresh(listBlogPostsProvider);
    smartRefresh(listSubscribedSpacesProvider);
    smartRefresh(listSessionsHistoryProvider);
  }

  @override
  void dispose() {
    _reconnectedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityStreamProvider, (previous, next) {
      if (next.hasValue) {
        _updateConnectivityStatus(next.value!);
      }
    });

    final shouldShow = _status != ConnectivityStatus.online;

    return SafeArea(
      left: shouldShow,
      top: shouldShow,
      right: shouldShow,
      bottom: shouldShow,
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
