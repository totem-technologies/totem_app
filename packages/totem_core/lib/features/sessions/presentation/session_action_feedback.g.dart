// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_action_feedback.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Room-level channel for failed manual actions.
///
/// Actions report here instead of using a [BuildContext] that may already be
/// gone, for example when a dialog closes. [SessionActionFeedbackEffects]
/// presents each report on the room's shared notification queue.

@ProviderFor(SessionActionFeedback)
final sessionActionFeedbackProvider = SessionActionFeedbackProvider._();

/// Room-level channel for failed manual actions.
///
/// Actions report here instead of using a [BuildContext] that may already be
/// gone, for example when a dialog closes. [SessionActionFeedbackEffects]
/// presents each report on the room's shared notification queue.
final class SessionActionFeedbackProvider
    extends $NotifierProvider<SessionActionFeedback, SessionActionReport?> {
  /// Room-level channel for failed manual actions.
  ///
  /// Actions report here instead of using a [BuildContext] that may already be
  /// gone, for example when a dialog closes. [SessionActionFeedbackEffects]
  /// presents each report on the room's shared notification queue.
  SessionActionFeedbackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionActionFeedbackProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[
          sessionScopeProvider,
          currentSessionStateProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionActionFeedbackProvider.$allTransitiveDependencies0,
          SessionActionFeedbackProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = sessionScopeProvider;
  static final $allTransitiveDependencies1 = currentSessionStateProvider;

  @override
  String debugGetCreateSourceHash() => _$sessionActionFeedbackHash();

  @$internal
  @override
  SessionActionFeedback create() => SessionActionFeedback();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionActionReport? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionActionReport?>(value),
    );
  }
}

String _$sessionActionFeedbackHash() =>
    r'935a4e49c824030a591ad403306900a7d5306dbc';

/// Room-level channel for failed manual actions.
///
/// Actions report here instead of using a [BuildContext] that may already be
/// gone, for example when a dialog closes. [SessionActionFeedbackEffects]
/// presents each report on the room's shared notification queue.

abstract class _$SessionActionFeedback extends $Notifier<SessionActionReport?> {
  SessionActionReport? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionActionReport?, SessionActionReport?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionActionReport?, SessionActionReport?>,
              SessionActionReport?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
