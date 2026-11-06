import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

part 'session_admission_settings.g.dart';

@Riverpod(dependencies: [sessionScope])
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

    return _enabledOverride ?? true;
  }

  void setEnabled(bool enabled) {
    _enabledOverride = enabled;
    state = enabled;
  }
}
