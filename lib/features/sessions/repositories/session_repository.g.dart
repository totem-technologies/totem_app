// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionToken)
const sessionTokenProvider = SessionTokenFamily._();

final class SessionTokenProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  const SessionTokenProvider._({
    required SessionTokenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sessionTokenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionTokenHash();

  @override
  String toString() {
    return r'sessionTokenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return sessionToken(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionTokenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionTokenHash() => r'849b90e856cbe312b13624b9feab25626bf69a2d';

final class SessionTokenFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  const SessionTokenFamily._()
    : super(
        retry: null,
        name: r'sessionTokenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionTokenProvider call(String eventSlug) =>
      SessionTokenProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'sessionTokenProvider';
}
