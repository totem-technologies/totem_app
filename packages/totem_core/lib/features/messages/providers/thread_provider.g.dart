// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThreadNotifier)
final threadProvider = ThreadNotifierFamily._();

final class ThreadNotifierProvider
    extends $AsyncNotifierProvider<ThreadNotifier, List<Message>> {
  ThreadNotifierProvider._({
    required ThreadNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'threadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$threadNotifierHash();

  @override
  String toString() {
    return r'threadProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ThreadNotifier create() => ThreadNotifier();

  @override
  bool operator ==(Object other) {
    return other is ThreadNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$threadNotifierHash() => r'bb55d2342514062699cf069a1a1304f5b729c7e5';

final class ThreadNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ThreadNotifier,
          AsyncValue<List<Message>>,
          List<Message>,
          FutureOr<List<Message>>,
          String
        > {
  ThreadNotifierFamily._()
    : super(
        retry: null,
        name: r'threadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ThreadNotifierProvider call(String conversationId) =>
      ThreadNotifierProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'threadProvider';
}

abstract class _$ThreadNotifier extends $AsyncNotifier<List<Message>> {
  late final _$args = ref.$arg as String;
  String get conversationId => _$args;

  FutureOr<List<Message>> build(String conversationId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Message>>, List<Message>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Message>>, List<Message>>,
              AsyncValue<List<Message>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
