// We are not importing firebase_core_platform_interface directly
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/src/pigeon/mocks.dart'
    show setupFirebaseCoreMocks;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void setupDotenv() {
  dotenv
    ..clean()
    ..loadFromString(
      envString: '{}',
    );
}

void silenceLogger() {
  Logger.level = Level.off;
}

Future<void> setupFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();

  await Firebase.initializeApp(
    name: 'test_app',
    options: const FirebaseOptions(
      apiKey: 'test_api_key',
      appId: 'test_app_id',
      messagingSenderId: 'test_messaging_sender_id',
      projectId: 'test_project_id',
    ),
  );
}
