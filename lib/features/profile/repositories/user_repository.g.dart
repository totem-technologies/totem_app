// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userProfile)
const userProfileProvider = UserProfileFamily._();

final class UserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<PublicUserSchema>,
          PublicUserSchema,
          FutureOr<PublicUserSchema>
        >
    with $FutureModifier<PublicUserSchema>, $FutureProvider<PublicUserSchema> {
  const UserProfileProvider._({
    required UserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userProfileHash();

  @override
  String toString() {
    return r'userProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PublicUserSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PublicUserSchema> create(Ref ref) {
    final argument = this.argument as String;
    return userProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userProfileHash() => r'4f6bc67ac93735a53c057c6af11d91cd3b15d4f3';

final class UserProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PublicUserSchema>, String> {
  const UserProfileFamily._()
    : super(
        retry: null,
        name: r'userProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserProfileProvider call(String slug) =>
      UserProfileProvider._(argument: slug, from: this);

  @override
  String toString() => r'userProfileProvider';
}

@ProviderFor(submitFeedback)
const submitFeedbackProvider = SubmitFeedbackFamily._();

final class SubmitFeedbackProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const SubmitFeedbackProvider._({
    required SubmitFeedbackFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'submitFeedbackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$submitFeedbackHash();

  @override
  String toString() {
    return r'submitFeedbackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return submitFeedback(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SubmitFeedbackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$submitFeedbackHash() => r'c9a91a1e420a2c70df2bc60c545fb6a7d83ec9df';

final class SubmitFeedbackFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const SubmitFeedbackFamily._()
    : super(
        retry: null,
        name: r'submitFeedbackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SubmitFeedbackProvider call(String feedback) =>
      SubmitFeedbackProvider._(argument: feedback, from: this);

  @override
  String toString() => r'submitFeedbackProvider';
}
