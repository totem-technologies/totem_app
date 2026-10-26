import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../check_omittable_interpolation.dart';

void main() {
  test('flags an interpolated Omittable, not its value', () async {
    final dir = Directory('.dart_tool/check_omittable_interpolation_test')
      ..createSync(recursive: true);
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/sample.dart').writeAsStringSync('''
class Omittable<T> {
  const Omittable(this.value);
  final T value;
}

const name = Omittable<String?>('Ada');
final wrong = 'with \${name}';
final right = 'with \${name.value}';
''');

    final found = await findOmittableInterpolations([dir.path]);

    check(found).length.equals(1);
    check(found.single).endsWith('sample.dart:7: name');
  });

  test(
    'the apps interpolate no Omittable fields',
    () async {
      // Run from the repository root, as `make test-scripts` does.
      final found = await findOmittableInterpolations(defaultRoots);

      check(found).isEmpty();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
