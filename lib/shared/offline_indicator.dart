import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

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
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(8),
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

class OfflineIndicatorPage extends StatefulWidget {
  const OfflineIndicatorPage({required this.child, super.key});

  final Widget child;

  @override
  State<OfflineIndicatorPage> createState() => _OfflineIndicatorPageState();
}

class _OfflineIndicatorPageState extends State<OfflineIndicatorPage> {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  ConnectivityStatus _status = ConnectivityStatus.online;
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectivityStatus,
    );
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
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

  @override
  void dispose() {
    _subscription.cancel();
    _reconnectedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
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
