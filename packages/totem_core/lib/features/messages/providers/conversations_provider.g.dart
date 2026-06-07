// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(conversations)
final conversationsProvider = ConversationsProvider._();

final class ConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          FutureOr<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $FutureProvider<List<Conversation>> {
  ConversationsProvider._()
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
  String debugGetCreateSourceHash() => _$conversationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Conversation>> create(Ref ref) {
    return conversations(ref);
  }
}

String _$conversationsHash() => r'0579fdeb203cb819462bce09604c1c46fcdfe6b7';
