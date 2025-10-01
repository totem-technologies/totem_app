import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/services/connectivity_service.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/logger.dart';

enum ConnectivityStatus { offline, online, recentlyReconnected }

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final ConnectivityStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOffline = status == ConnectivityStatus.offline;
    final text = isOffline ? 'You are offline' : "You're back online";
    final backgroundColor = isOffline ? Colors.white : Colors.green.shade100;
    final textColor = isOffline
        ? theme.colorScheme.onSurface
        : Colors.green.shade900;

    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        padding: const EdgeInsetsDirectional.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: kElevationToShadow[1],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
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
    void smartRefresh(ProviderOrFamily provider) {
      // Workaround for the riverpod typing inconsistency
      if (!((ref.read(provider as ProviderListenable) as dynamic).hasValue
          as bool)) {
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
    ref.listen(
      connectivityStreamProvider,
      (previous, next) {
        if (next.hasValue) {
          _updateConnectivityStatus(next.value!);
        }
      },
    );

    return Stack(
      fit: StackFit.expand,
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        Positioned.fill(child: widget.child),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1.5),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: _status != ConnectivityStatus.online
              ? _StatusBanner(status: _status)
              : const SizedBox.shrink(key: ValueKey('online')),
        ),
      ],
    );
  }
}
