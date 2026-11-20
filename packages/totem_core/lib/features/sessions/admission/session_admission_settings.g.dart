// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_admission_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionAdmissionSettings)
final sessionAdmissionSettingsProvider = SessionAdmissionSettingsProvider._();

final class SessionAdmissionSettingsProvider
    extends $NotifierProvider<SessionAdmissionSettings, bool> {
  SessionAdmissionSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionAdmissionSettingsProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[
          sessionScopeProvider,
          currentSessionProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionAdmissionSettingsProvider.$allTransitiveDependencies0,
          SessionAdmissionSettingsProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = sessionScopeProvider;
  static final $allTransitiveDependencies1 = currentSessionProvider;

  @override
  String debugGetCreateSourceHash() => _$sessionAdmissionSettingsHash();

  @$internal
  @override
  SessionAdmissionSettings create() => SessionAdmissionSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$sessionAdmissionSettingsHash() =>
    r'e7460db9f2325c05634ee6dd31d313c9ba39e122';

abstract class _$SessionAdmissionSettings extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
