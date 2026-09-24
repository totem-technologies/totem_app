import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../totem_core/test/leak_testing_setup.dart';

Future<void> testExecutable(AsyncCallback testMain) async {
  configureTotemLeakTesting();

  await testMain();
}
