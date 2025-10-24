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

String _$userProfileHash() => r'4a5010b40e22c98352d50d8df2057455f4112ce6';

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
