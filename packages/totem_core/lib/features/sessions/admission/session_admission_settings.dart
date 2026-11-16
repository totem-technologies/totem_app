import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

part 'session_admission_settings.g.dart';

@Riverpod(dependencies: [sessionScope, currentSession])
class SessionAdmissionSettings extends _$SessionAdmissionSettings {
  String? _sessionSlug;
  bool? _enabledOverride;

  @override
  bool build() {
    final sessionSlug = ref.watch(sessionScopeProvider)?.sessionSlug;
    if (_sessionSlug != sessionSlug) {
      _sessionSlug = sessionSlug;
      _enabledOverride = null;
    }

    final candidate = ref.watch(currentSessionProvider)?.admission;
    final service = candidate?.mounted == true ? candidate : null;
    final enabled = _enabledOverride ?? service?.approvalRequired ?? true;
    return enabled;
  }

  void setEnabled(bool enabled) {
    _enabledOverride = enabled;
    state = enabled;
    final candidate = ref.read(currentSessionProvider)?.admission;
    if (candidate?.mounted == true) {
      candidate!.setApprovalRequired(enabled);
    }
  }
}
