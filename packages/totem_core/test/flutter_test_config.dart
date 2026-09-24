import 'dart:async';

import 'leak_testing_setup.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  configureTotemLeakTesting();

  await testMain();
}
