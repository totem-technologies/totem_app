import 'package:firebase_core/firebase_core.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/firebase_options.dart';
import 'package:totem_app/shared/logger.dart';

class FirebaseService {
  const FirebaseService._();

  static const FirebaseService instance = FirebaseService._();

  /// Whether firebase is initialized.
  bool get isInitialized => Firebase.apps.isNotEmpty;

  /// Initializes Firebase.
  ///
  /// If already initialized, this method does nothing.
  ///
  /// If the initialization fails, the error is handled gracefully and logged.
  Future<void> initialize() async {
    if (isInitialized) {
      logger.i('⚠️ FirebaseService is already initialized.');
      return;
    }

    logger.i('🚀 Initializing FirebaseService...');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.i('✅ FirebaseService initialized.');
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        message: 'FirebaseService initialization error',
      );
    }
  }
}
