// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_admission_roster.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(KeeperAdmissionRoster)
final keeperAdmissionRosterProvider = KeeperAdmissionRosterFamily._();

final class KeeperAdmissionRosterProvider
    extends
        $AsyncNotifierProvider<
          KeeperAdmissionRoster,
          KeeperAdmissionRosterStore
        > {
  KeeperAdmissionRosterProvider._({
    required KeeperAdmissionRosterFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'keeperAdmissionRosterProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$keeperAdmissionRosterHash();

  @override
  String toString() {
    return r'keeperAdmissionRosterProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  KeeperAdmissionRoster create() => KeeperAdmissionRoster();

  @override
  bool operator ==(Object other) {
    return other is KeeperAdmissionRosterProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$keeperAdmissionRosterHash() =>
    r'67c580a2db396d212de815ac4481ed8a6d4ca638';

final class KeeperAdmissionRosterFamily extends $Family
    with
        $ClassFamilyOverride<
          KeeperAdmissionRoster,
          AsyncValue<KeeperAdmissionRosterStore>,
          KeeperAdmissionRosterStore,
          FutureOr<KeeperAdmissionRosterStore>,
          (String, String)
        > {
  KeeperAdmissionRosterFamily._()
    : super(
        retry: null,
        name: r'keeperAdmissionRosterProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  KeeperAdmissionRosterProvider call(
    String sessionSlug,
    String keeperIdentity,
  ) => KeeperAdmissionRosterProvider._(
    argument: (sessionSlug, keeperIdentity),
    from: this,
  );

  @override
  String toString() => r'keeperAdmissionRosterProvider';
}

abstract class _$KeeperAdmissionRoster
    extends $AsyncNotifier<KeeperAdmissionRosterStore> {
  late final _$args = ref.$arg as (String, String);
  String get sessionSlug => _$args.$1;
  String get keeperIdentity => _$args.$2;

  FutureOr<KeeperAdmissionRosterStore> build(
    String sessionSlug,
    String keeperIdentity,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<KeeperAdmissionRosterStore>,
              KeeperAdmissionRosterStore
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<KeeperAdmissionRosterStore>,
                KeeperAdmissionRosterStore
              >,
              AsyncValue<KeeperAdmissionRosterStore>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
