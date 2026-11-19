// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emoji_reactions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EmojiReactions)
final emojiReactionsProvider = EmojiReactionsProvider._();

final class EmojiReactionsProvider
    extends $NotifierProvider<EmojiReactions, List<SessionEmojiReaction>> {
  EmojiReactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emojiReactionsProvider',
        isAutoDispose: false,
        dependencies: <ProviderOrFamily>[currentSessionProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          EmojiReactionsProvider.$allTransitiveDependencies0,
          EmojiReactionsProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$emojiReactionsHash();

  @$internal
  @override
  EmojiReactions create() => EmojiReactions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SessionEmojiReaction> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SessionEmojiReaction>>(value),
    );
  }
}

String _$emojiReactionsHash() => r'e7ab827932f5c2da57b11787c0e9dcade8dac444';

abstract class _$EmojiReactions extends $Notifier<List<SessionEmojiReaction>> {
  List<SessionEmojiReaction> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<List<SessionEmojiReaction>, List<SessionEmojiReaction>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                List<SessionEmojiReaction>,
                List<SessionEmojiReaction>
              >,
              List<SessionEmojiReaction>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(participantEmojis)
final participantEmojisProvider = ParticipantEmojisFamily._();

final class ParticipantEmojisProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  ParticipantEmojisProvider._({
    required ParticipantEmojisFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'participantEmojisProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  static final $allTransitiveDependencies0 = emojiReactionsProvider;
  static final $allTransitiveDependencies1 =
      EmojiReactionsProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      EmojiReactionsProvider.$allTransitiveDependencies1;

  @override
  String debugGetCreateSourceHash() => _$participantEmojisHash();

  @override
  String toString() {
    return r'participantEmojisProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    final argument = this.argument as String;
    return participantEmojis(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ParticipantEmojisProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$participantEmojisHash() => r'd401629ab168d38465e40e9268445eff1087eff8';

final class ParticipantEmojisFamily extends $Family
    with $FunctionalFamilyOverride<List<String>, String> {
  ParticipantEmojisFamily._()
    : super(
        retry: null,
        name: r'participantEmojisProvider',
        dependencies: <ProviderOrFamily>[emojiReactionsProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ParticipantEmojisProvider.$allTransitiveDependencies0,
          ParticipantEmojisProvider.$allTransitiveDependencies1,
          ParticipantEmojisProvider.$allTransitiveDependencies2,
        ],
        isAutoDispose: true,
      );

  ParticipantEmojisProvider call(String participantIdentity) =>
      ParticipantEmojisProvider._(argument: participantIdentity, from: this);

  @override
  String toString() => r'participantEmojisProvider';
}
