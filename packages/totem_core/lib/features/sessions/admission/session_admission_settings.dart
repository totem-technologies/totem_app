import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart' show RoomStatus;

import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

part 'session_admission_settings.g.dart';

@Riverpod(dependencies: [sessionScope, roomStatus])
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

    final status = ref.watch(roomStatusProvider);
    return _enabledOverride ?? _defaultEnabled(status);
  }

  void setEnabled(bool enabled) {
    _enabledOverride = enabled;
    state = enabled;
  }

  bool _defaultEnabled(RoomStatus status) => true;
}
