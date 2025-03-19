import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import '../core/services/deep_link_service.dart';

/// TotemApp serves as the root widget that initializes app-wide services
/// and handles deep links before presenting the main App widget
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

    // Handle app lifecycle changes for deep links and other services
    if (state == AppLifecycleState.resumed) {
      _deepLinkService.handleIncomingLinks();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize deep link handling
      await _deepLinkService.initialize();

      // Set up initial deep link if app was opened with one
      await _deepLinkService.handleInitialLink();

      // Start listening for future deep links
      _deepLinkService.handleIncomingLinks();

      // Mark initialization as complete
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      // Continue to show app even if deep link handling fails
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while initializing
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Show the main app once initialized
    return const App();
  }
}
