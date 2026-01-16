// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emoji_reactions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages emoji reactions state for all participants in a session.
///
/// Reactions are automatically removed after the animation duration (2 seconds).
/// This prevents full VideoRoomScreen rebuilds by isolating emoji state.

@ProviderFor(EmojiReactions)
final emojiReactionsProvider = EmojiReactionsProvider._();

/// Manages emoji reactions state for all participants in a session.
///
/// Reactions are automatically removed after the animation duration (2 seconds).
/// This prevents full VideoRoomScreen rebuilds by isolating emoji state.
final class EmojiReactionsProvider
    extends $NotifierProvider<EmojiReactions, List<MapEntry<String, String>>> {
  /// Manages emoji reactions state for all participants in a session.
  ///
  /// Reactions are automatically removed after the animation duration (2 seconds).
  /// This prevents full VideoRoomScreen rebuilds by isolating emoji state.
  EmojiReactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emojiReactionsProvider',
        isAutoDispose: true,
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

String _$emojiReactionsHash() => r'08e118c2952e9c82e6f61f4e1b26b79decb9afae';

/// Manages emoji reactions state for all participants in a session.
///
/// Reactions are automatically removed after the animation duration (2 seconds).
/// This prevents full VideoRoomScreen rebuilds by isolating emoji state.

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

/// Provides filtered emojis for a specific participant.
///
/// This prevents unnecessary rebuilds - only the specific ParticipantCard
/// watching this provider will rebuild when its emoji changes.

@ProviderFor(participantEmojis)
final participantEmojisProvider = ParticipantEmojisFamily._();

/// Provides filtered emojis for a specific participant.
///
/// This prevents unnecessary rebuilds - only the specific ParticipantCard
/// watching this provider will rebuild when its emoji changes.

final class ParticipantEmojisProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Provides filtered emojis for a specific participant.
  ///
  /// This prevents unnecessary rebuilds - only the specific ParticipantCard
  /// watching this provider will rebuild when its emoji changes.
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

String _$participantEmojisHash() => r'f07aac6557279b4153040d8331100a3eee6c7c54';

/// Provides filtered emojis for a specific participant.
///
/// This prevents unnecessary rebuilds - only the specific ParticipantCard
/// watching this provider will rebuild when its emoji changes.

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

  /// Provides filtered emojis for a specific participant.
  ///
  /// This prevents unnecessary rebuilds - only the specific ParticipantCard
  /// watching this provider will rebuild when its emoji changes.

  ParticipantEmojisProvider call(String participantIdentity) =>
      ParticipantEmojisProvider._(argument: participantIdentity, from: this);

  @override
  String toString() => r'participantEmojisProvider';
}
