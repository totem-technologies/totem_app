// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThreadNotifier)
final threadNotifierProvider = ThreadNotifierFamily._();

final class ThreadNotifierProvider
    extends $AsyncNotifierProvider<ThreadNotifier, List<Message>> {
  ThreadNotifierProvider._({
    required ThreadNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'threadNotifierProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$threadNotifierHash();

  @override
  String toString() {
    return r'threadNotifierProvider'
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

String _$threadNotifierHash() => r'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2';

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
        name: r'threadNotifierProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ThreadNotifierProvider call(String conversationId) =>
      ThreadNotifierProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'threadNotifierProvider';
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
