import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/widgets/update_alert.dart';

void main() {
  group('hasMinorVersionUpdate', () {
    test('prompts when the second version component changes', () {
      check(hasMinorVersionUpdate('0.0.1', '0.1.0')).isTrue();
      check(hasMinorVersionUpdate('0.1.10', '0.2.0')).isTrue();
      check(hasMinorVersionUpdate('1.4.2', '1.5.0')).isTrue();
    });

    test('does not prompt for patch or first-component-only changes', () {
      check(hasMinorVersionUpdate('0.1.10', '0.1.11')).isFalse();
      check(hasMinorVersionUpdate('1.4.2', '2.4.0')).isFalse();
    });

    test('does not prompt when either version is unavailable or invalid', () {
      check(hasMinorVersionUpdate(null, '0.1.0')).isFalse();
      check(hasMinorVersionUpdate('0.1.0', 'invalid')).isFalse();
    });
  });
}
