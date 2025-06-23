import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'You are offline',
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
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
  late final StreamSubscription<List<ConnectivityResult>> subscription;

  var _isOffline = false;

  @override
  void initState() {
    super.initState();
    subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      setState(() {
        _isOffline = result.isEmpty || result.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    subscription.cancel();
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
          duration: const Duration(milliseconds: 300),
          child: _isOffline
              ? const OfflineIndicator()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
