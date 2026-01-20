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
    extends $NotifierProvider<EmojiReactions, List<MapEntry<String, String>>> {
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
  Override overrideWithValue(List<MapEntry<String, String>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MapEntry<String, String>>>(
        value,
      ),
    );
  }
}

String _$emojiReactionsHash() => r'd4414132d57ef84d831ee2e01a290c1a04b4f4bf';

abstract class _$EmojiReactions
    extends $Notifier<List<MapEntry<String, String>>> {
  List<MapEntry<String, String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              List<MapEntry<String, String>>,
              List<MapEntry<String, String>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                List<MapEntry<String, String>>,
                List<MapEntry<String, String>>
              >,
              List<MapEntry<String, String>>,
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
         isAutoDispose: false,
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

String _$participantEmojisHash() => r'780e9fb2b3060cbb6f63f21edb4d81e9ae3f69f4';

final class ParticipantEmojisFamily extends $Family
    with $FunctionalFamilyOverride<List<String>, String> {
  ParticipantEmojisFamily._()
    : super(
        retry: null,
        name: r'participantEmojisProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ParticipantEmojisProvider call(String participantIdentity) =>
      ParticipantEmojisProvider._(argument: participantIdentity, from: this);

  @override
  String toString() => r'participantEmojisProvider';
}
