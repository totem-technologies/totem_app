import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/deep_link_service.dart';
import 'app.dart';

class TotemApp extends ConsumerStatefulWidget {
  const TotemApp({super.key});

  @override
  ConsumerState<TotemApp> createState() => _TotemAppState();
}

class _TotemAppState extends ConsumerState<TotemApp>
    with WidgetsBindingObserver {
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _deepLinkService.handleIncomingLinks();
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _deepLinkService.initialize();
      await _deepLinkService.handleInitialLink();

      _deepLinkService.handleIncomingLinks();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return const App();
  }
}
