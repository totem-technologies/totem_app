// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compose_to_participants_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Compose state for broadcasting a message to a session's participants.
///
/// The family is keyed by [sessionSlug] so selection survives rebuilds even
/// when the recipient list is a freshly-allocated `List` from a future
/// backend provider. Do not key on the list itself — that would reset the
/// notifier on every rebuild.

@ProviderFor(ComposeToParticipantsNotifier)
final composeToParticipantsProvider = ComposeToParticipantsNotifierFamily._();

/// Compose state for broadcasting a message to a session's participants.
///
/// The family is keyed by [sessionSlug] so selection survives rebuilds even
/// when the recipient list is a freshly-allocated `List` from a future
/// backend provider. Do not key on the list itself — that would reset the
/// notifier on every rebuild.
final class ComposeToParticipantsNotifierProvider
    extends
        $NotifierProvider<
          ComposeToParticipantsNotifier,
          ComposeToParticipantsState
        > {
  /// Compose state for broadcasting a message to a session's participants.
  ///
  /// The family is keyed by [sessionSlug] so selection survives rebuilds even
  /// when the recipient list is a freshly-allocated `List` from a future
  /// backend provider. Do not key on the list itself — that would reset the
  /// notifier on every rebuild.
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
    r'1f04235fd48d0a416a91ae8cc44411e07d8f872e';

/// Compose state for broadcasting a message to a session's participants.
///
/// The family is keyed by [sessionSlug] so selection survives rebuilds even
/// when the recipient list is a freshly-allocated `List` from a future
/// backend provider. Do not key on the list itself — that would reset the
/// notifier on every rebuild.

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

  /// Compose state for broadcasting a message to a session's participants.
  ///
  /// The family is keyed by [sessionSlug] so selection survives rebuilds even
  /// when the recipient list is a freshly-allocated `List` from a future
  /// backend provider. Do not key on the list itself — that would reset the
  /// notifier on every rebuild.

  ComposeToParticipantsNotifierProvider call(String sessionSlug) =>
      ComposeToParticipantsNotifierProvider._(
        argument: sessionSlug,
        from: this,
      );

  @override
  String toString() => r'composeToParticipantsProvider';
}

/// Compose state for broadcasting a message to a session's participants.
///
/// The family is keyed by [sessionSlug] so selection survives rebuilds even
/// when the recipient list is a freshly-allocated `List` from a future
/// backend provider. Do not key on the list itself — that would reset the
/// notifier on every rebuild.

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
