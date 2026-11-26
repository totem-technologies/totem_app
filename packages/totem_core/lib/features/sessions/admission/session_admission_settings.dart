import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

part 'session_admission_settings.g.dart';

@Riverpod(dependencies: [sessionScope, currentSession])
class SessionAdmissionSettings extends _$SessionAdmissionSettings {
  @override
  bool build() {
    final candidate = ref.watch(currentSessionProvider)?.admission;
    final service = candidate?.mounted == true ? candidate : null;
    if (service != null) {
      void changed() {
        if (ref.mounted && service.mounted) state = service.approvalRequired;
      }

      service.addListener(changed);
      ref.onDispose(() => service.removeListener(changed));
    }
    return service?.approvalRequired ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final service = ref.read(currentSessionProvider)?.admission;
    if (service?.mounted == true) await service!.setApprovalRequired(enabled);
  }
}
