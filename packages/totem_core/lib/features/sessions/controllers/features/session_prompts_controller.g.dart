// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_prompts_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sole client-side owner of a session's prepared-prompt collection.
///
/// It is deliberately kept alive: an HTTP mutation belongs to the session, not
/// to the transient modal that started it.

@ProviderFor(SessionPromptsController)
final sessionPromptsControllerProvider = SessionPromptsControllerFamily._();

/// The sole client-side owner of a session's prepared-prompt collection.
///
/// It is deliberately kept alive: an HTTP mutation belongs to the session, not
/// to the transient modal that started it.
final class SessionPromptsControllerProvider
    extends $NotifierProvider<SessionPromptsController, SessionPromptsState> {
  /// The sole client-side owner of a session's prepared-prompt collection.
  ///
  /// It is deliberately kept alive: an HTTP mutation belongs to the session, not
  /// to the transient modal that started it.
  SessionPromptsControllerProvider._({
    required SessionPromptsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sessionPromptsControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionPromptsControllerHash();

  @override
  String toString() {
    return r'sessionPromptsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionPromptsController create() => SessionPromptsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionPromptsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionPromptsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionPromptsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionPromptsControllerHash() =>
    r'e79214924ef233683d6dd8517246e6fe909492a9';

/// The sole client-side owner of a session's prepared-prompt collection.
///
/// It is deliberately kept alive: an HTTP mutation belongs to the session, not
/// to the transient modal that started it.

final class SessionPromptsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionPromptsController,
          SessionPromptsState,
          SessionPromptsState,
          SessionPromptsState,
          String
        > {
  SessionPromptsControllerFamily._()
    : super(
        retry: null,
        name: r'sessionPromptsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The sole client-side owner of a session's prepared-prompt collection.
  ///
  /// It is deliberately kept alive: an HTTP mutation belongs to the session, not
  /// to the transient modal that started it.

  SessionPromptsControllerProvider call(String sessionSlug) =>
      SessionPromptsControllerProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'sessionPromptsControllerProvider';
}

/// The sole client-side owner of a session's prepared-prompt collection.
///
/// It is deliberately kept alive: an HTTP mutation belongs to the session, not
/// to the transient modal that started it.

abstract class _$SessionPromptsController
    extends $Notifier<SessionPromptsState> {
  late final _$args = ref.$arg as String;
  String get sessionSlug => _$args;

  SessionPromptsState build(String sessionSlug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionPromptsState, SessionPromptsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionPromptsState, SessionPromptsState>,
              SessionPromptsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
