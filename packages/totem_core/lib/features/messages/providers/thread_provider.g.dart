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
    extends $AsyncNotifierProvider<ThreadNotifier, ThreadState> {
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

String _$threadNotifierHash() => r'a31d9438274ad038ab40b7f8d52c756af4a132ce';

final class ThreadNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ThreadNotifier,
          AsyncValue<ThreadState>,
          ThreadState,
          FutureOr<ThreadState>,
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

abstract class _$ThreadNotifier extends $AsyncNotifier<ThreadState> {
  late final _$args = ref.$arg as String;
  String get conversationId => _$args;

  FutureOr<ThreadState> build(String conversationId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThreadState>, ThreadState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThreadState>, ThreadState>,
              AsyncValue<ThreadState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
