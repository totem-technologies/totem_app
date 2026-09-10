// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConversationsNotifier)
final conversationsProvider = ConversationsNotifierProvider._();

final class ConversationsNotifierProvider
    extends $AsyncNotifierProvider<ConversationsNotifier, InboxState> {
  ConversationsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsNotifierHash();

  @$internal
  @override
  ConversationsNotifier create() => ConversationsNotifier();
}

String _$conversationsNotifierHash() =>
    r'31703325f99e8c7a773270a1aa869bc2c02257c7';

abstract class _$ConversationsNotifier extends $AsyncNotifier<InboxState> {
  FutureOr<InboxState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<InboxState>, InboxState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<InboxState>, InboxState>,
              AsyncValue<InboxState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(conversationById)
final conversationByIdProvider = ConversationByIdFamily._();

final class ConversationByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Conversation>,
          Conversation,
          FutureOr<Conversation>
        >
    with $FutureModifier<Conversation>, $FutureProvider<Conversation> {
  ConversationByIdProvider._({
    required ConversationByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationByIdHash();

  @override
  String toString() {
    return r'conversationByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Conversation> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Conversation> create(Ref ref) {
    final argument = this.argument as String;
    return conversationById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationByIdHash() => r'3c1c8e032b96b6ee770d42fea6d9229a907efcc5';

final class ConversationByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Conversation>, String> {
  ConversationByIdFamily._()
    : super(
        retry: null,
        name: r'conversationByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationByIdProvider call(String conversationId) =>
      ConversationByIdProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationByIdProvider';
}

@ProviderFor(RecipientDirectoryNotifier)
final recipientDirectoryProvider = RecipientDirectoryNotifierFamily._();

final class RecipientDirectoryNotifierProvider
    extends
        $AsyncNotifierProvider<
          RecipientDirectoryNotifier,
          RecipientDirectoryState
        > {
  RecipientDirectoryNotifierProvider._({
    required RecipientDirectoryNotifierFamily super.from,
    required RecipientDirectoryKind super.argument,
  }) : super(
         retry: null,
         name: r'recipientDirectoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recipientDirectoryNotifierHash();

  @override
  String toString() {
    return r'recipientDirectoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RecipientDirectoryNotifier create() => RecipientDirectoryNotifier();

  @override
  bool operator ==(Object other) {
    return other is RecipientDirectoryNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recipientDirectoryNotifierHash() =>
    r'5e437c8571f74ce6a0793341e5b956e92ab23c3a';

final class RecipientDirectoryNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          RecipientDirectoryNotifier,
          AsyncValue<RecipientDirectoryState>,
          RecipientDirectoryState,
          FutureOr<RecipientDirectoryState>,
          RecipientDirectoryKind
        > {
  RecipientDirectoryNotifierFamily._()
    : super(
        retry: null,
        name: r'recipientDirectoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecipientDirectoryNotifierProvider call(RecipientDirectoryKind kind) =>
      RecipientDirectoryNotifierProvider._(argument: kind, from: this);

  @override
  String toString() => r'recipientDirectoryProvider';
}

abstract class _$RecipientDirectoryNotifier
    extends $AsyncNotifier<RecipientDirectoryState> {
  late final _$args = ref.$arg as RecipientDirectoryKind;
  RecipientDirectoryKind get kind => _$args;

  FutureOr<RecipientDirectoryState> build(RecipientDirectoryKind kind);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<RecipientDirectoryState>,
              RecipientDirectoryState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<RecipientDirectoryState>,
                RecipientDirectoryState
              >,
              AsyncValue<RecipientDirectoryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(SessionMessageParticipantsNotifier)
final sessionMessageParticipantsProvider =
    SessionMessageParticipantsNotifierFamily._();

final class SessionMessageParticipantsNotifierProvider
    extends
        $AsyncNotifierProvider<
          SessionMessageParticipantsNotifier,
          SessionParticipantsState
        > {
  SessionMessageParticipantsNotifierProvider._({
    required SessionMessageParticipantsNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sessionMessageParticipantsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$sessionMessageParticipantsNotifierHash();

  @override
  String toString() {
    return r'sessionMessageParticipantsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionMessageParticipantsNotifier create() =>
      SessionMessageParticipantsNotifier();

  @override
  bool operator ==(Object other) {
    return other is SessionMessageParticipantsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionMessageParticipantsNotifierHash() =>
    r'9196c9b98c2ed85a5059cfe5edd6aade17753256';

final class SessionMessageParticipantsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionMessageParticipantsNotifier,
          AsyncValue<SessionParticipantsState>,
          SessionParticipantsState,
          FutureOr<SessionParticipantsState>,
          String
        > {
  SessionMessageParticipantsNotifierFamily._()
    : super(
        retry: null,
        name: r'sessionMessageParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionMessageParticipantsNotifierProvider call(String sessionSlug) =>
      SessionMessageParticipantsNotifierProvider._(
        argument: sessionSlug,
        from: this,
      );

  @override
  String toString() => r'sessionMessageParticipantsProvider';
}

abstract class _$SessionMessageParticipantsNotifier
    extends $AsyncNotifier<SessionParticipantsState> {
  late final _$args = ref.$arg as String;
  String get sessionSlug => _$args;

  FutureOr<SessionParticipantsState> build(String sessionSlug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SessionParticipantsState>,
              SessionParticipantsState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SessionParticipantsState>,
                SessionParticipantsState
              >,
              AsyncValue<SessionParticipantsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
