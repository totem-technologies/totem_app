// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compose_to_participants_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ComposeToParticipantsNotifier)
final composeToParticipantsProvider = ComposeToParticipantsNotifierFamily._();

final class ComposeToParticipantsNotifierProvider
    extends
        $NotifierProvider<
          ComposeToParticipantsNotifier,
          ComposeToParticipantsState
        > {
  ComposeToParticipantsNotifierProvider._({
    required ComposeToParticipantsNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'composeToParticipantsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$composeToParticipantsNotifierHash();

  @override
  String toString() {
    return r'composeToParticipantsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ComposeToParticipantsNotifier create() => ComposeToParticipantsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComposeToParticipantsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComposeToParticipantsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ComposeToParticipantsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$composeToParticipantsNotifierHash() =>
    r'b70dc19c9ab234c59d977f7d668d596084606377';

final class ComposeToParticipantsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ComposeToParticipantsNotifier,
          ComposeToParticipantsState,
          ComposeToParticipantsState,
          ComposeToParticipantsState,
          String
        > {
  ComposeToParticipantsNotifierFamily._()
    : super(
        retry: null,
        name: r'composeToParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ComposeToParticipantsNotifierProvider call(String sessionSlug) =>
      ComposeToParticipantsNotifierProvider._(
        argument: sessionSlug,
        from: this,
      );

  @override
  String toString() => r'composeToParticipantsProvider';
}

abstract class _$ComposeToParticipantsNotifier
    extends $Notifier<ComposeToParticipantsState> {
  late final _$args = ref.$arg as String;
  String get sessionSlug => _$args;

  ComposeToParticipantsState build(String sessionSlug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<ComposeToParticipantsState, ComposeToParticipantsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ComposeToParticipantsState,
                ComposeToParticipantsState
              >,
              ComposeToParticipantsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
