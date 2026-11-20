import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';

void main() {
  test(
    'does not optimistically change settings without an admission service',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        sessionAdmissionSettingsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      check(container.read(sessionAdmissionSettingsProvider)).isTrue();
      await container
          .read(sessionAdmissionSettingsProvider.notifier)
          .setEnabled(false);
      check(container.read(sessionAdmissionSettingsProvider)).isTrue();
    },
  );
}
