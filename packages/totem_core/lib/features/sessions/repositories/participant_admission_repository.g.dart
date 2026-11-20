// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participant_admission_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(participantAdmissionRepository)
final participantAdmissionRepositoryProvider =
    ParticipantAdmissionRepositoryProvider._();

final class ParticipantAdmissionRepositoryProvider
    extends
        $FunctionalProvider<
          ParticipantAdmissionRepository,
          ParticipantAdmissionRepository,
          ParticipantAdmissionRepository
        >
    with $Provider<ParticipantAdmissionRepository> {
  ParticipantAdmissionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'participantAdmissionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$participantAdmissionRepositoryHash();

  @$internal
  @override
  $ProviderElement<ParticipantAdmissionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ParticipantAdmissionRepository create(Ref ref) {
    return participantAdmissionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ParticipantAdmissionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ParticipantAdmissionRepository>(
        value,
      ),
    );
  }
}

String _$participantAdmissionRepositoryHash() =>
    r'461a6244a78412aa4ebe6df7d2b106f64222724d';
