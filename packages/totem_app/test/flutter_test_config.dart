import 'dart:async';

import '../../totem_core/test/leak_testing_setup.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  configureTotemLeakTesting();

  await testMain();
}
