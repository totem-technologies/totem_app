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
        dependencies: null,
        $allTransitiveDependencies: null,
      );

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

String _$emojiReactionsHash() => r'614f6cd2963b4cc9659411beb2216368a6d7e558';

abstract class _$EmojiReactions extends $Notifier<List<SessionEmojiReaction>> {
  List<SessionEmojiReaction> build();
  @$mustCallSuper
  @override
  void runBuild() {
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
    element.handleCreate(ref, build);
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

String _$participantEmojisHash() => r'0d53201459e39eb86879e4d0d0cdc1bd01a5e352';

final class ParticipantEmojisFamily extends $Family
    with $FunctionalFamilyOverride<List<String>, String> {
  ParticipantEmojisFamily._()
    : super(
        retry: null,
        name: r'participantEmojisProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ParticipantEmojisProvider call(String participantIdentity) =>
      ParticipantEmojisProvider._(argument: participantIdentity, from: this);

  @override
  String toString() => r'participantEmojisProvider';
}
