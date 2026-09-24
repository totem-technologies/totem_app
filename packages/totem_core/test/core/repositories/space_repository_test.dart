// Uses the generated client's existing transitive test adapter without adding a
// test-only dependency solely for repository boundary tests.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:checks/checks.dart';

import 'package:degenerate_runtime/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/cache_service.dart';
import 'package:totem_core/core/services/secure_storage.dart';

import '../../setup.dart';

class _FakeCache extends CacheService {
  _FakeCache({this.spaces, this.subscribed}) : super(SecureStorage());

  List<MobileSpaceDetailSchema>? spaces;
  List<SpaceSchema>? subscribed;
  int savedSpaces = 0;
  int savedSubscribed = 0;

  @override
  Future<List<MobileSpaceDetailSchema>?> getSpaces() async => spaces;

  @override
  Future<List<SpaceSchema>?> getSubscribedSpaces() async => subscribed;

  @override
  Future<void> saveSpaces(List<MobileSpaceDetailSchema> value) async {
    savedSpaces++;
  }

  @override
  Future<void> saveSubscribedSpaces(List<SpaceSchema> value) async {
    savedSubscribed++;
  }
}

MobileSpaceDetailSchema _space(String slug) => MobileSpaceDetailSchema(
  slug: slug,
  title: 'Space $slug',
  imageLink: null,
  shortDescription: 'Description',
  content: '',
  author: PublicUserSchema(
    profileAvatarType: ProfileAvatarTypeEnum.td,
    dateCreated: DateTime.utc(2026),
  ),
  category: null,
  subscribers: 2,
  recurring: null,
  price: 0,
  nextEvents: const [],
);

ClientApi _api(RecordingClient client) => ClientApi(ApiConfig(client: client));

ProviderContainer _container({
  required RecordingClient client,
  required _FakeCache cache,
}) => ProviderContainer(
  overrides: [
    apiServiceProvider.overrideWithValue(_api(client)),
    cacheServiceProvider.overrideWithValue(cache),
    listSubscribedSpacesProvider.overrideWith(
      (_) async => cache.subscribed ?? [],
    ),
  ],
);

void main() {
  setupAppConfig();

  group('space repository network boundaries', () {
    test(
      'returns cached spaces when the listing request has a network failure',
      () async {
        final cached = [_space('cached')];
        final client = RecordingClient(
          nextResponse: ApiResponse(statusCode: 503, body: 'unavailable'),
        );
        final cache = _FakeCache(spaces: cached);
        final container = _container(client: client, cache: cache);
        addTearDown(container.dispose);

        final result = await container.read(listSpacesProvider.future);

        check(result).deepEquals(cached);
        check(cache.savedSpaces).equals(0);
      },
    );

    test(
      'subscribes and unsubscribes through the public repository providers',
      () async {
        final client = RecordingClient(
          onRequest: (request) => ApiResponse(
            statusCode: 200,
            body: request.method == 'DELETE' ? 'true' : 'true',
          ),
        );
        final cache = _FakeCache(subscribed: []);
        final container = _container(client: client, cache: cache);
        addTearDown(container.dispose);

        check(
          await container.read(subscribeToSpaceProvider('wellbeing').future),
        ).isTrue();
        check(
          await container.read(
            unsubscribeFromSpaceProvider('wellbeing').future,
          ),
        ).isTrue();
        check(client.requests).length.equals(2);
        check(client.requests[0].method).equals('POST');
        check(client.requests[1].method).equals('DELETE');
        check(
          client.requests[0].path,
        ).equals('/api/mobile/protected/spaces/subscribe/wellbeing');
        check(
          client.requests[1].path,
        ).equals('/api/mobile/protected/spaces/subscribe/wellbeing');
      },
    );
  });

  test(
    'converts an RSVP conflict response into the app-owned exception',
    () async {
      final existing = _session('existing', attending: true);
      final conflict = SessionConflictSchema(
        message: 'Already attending',
        conflictingSessions: [existing],
      );
      final client = RecordingClient(
        nextResponse: ApiResponse(
          statusCode: 409,
          body: jsonEncode(conflict.toJson()),
        ),
      );
      final container = _container(client: client, cache: _FakeCache());
      addTearDown(container.dispose);

      RsvpConflictException? caught;
      try {
        await container.read(rsvpConfirmProvider('new').future);
      } on RsvpConflictException catch (error) {
        caught = error;
      }
      check(caught).isNotNull();
      check(
        caught!.conflict.conflictingSessions.single.slug,
      ).equals('existing');
    },
  );
}

SessionDetailSchema _session(String slug, {required bool attending}) =>
    SessionDetailSchema(
      slug: slug,
      title: 'Session $slug',
      space: _space('$slug-space'),
      content: '',
      seatsLeft: 3,
      duration: 60,
      start: DateTime.utc(2026, 8, 20, 15),
      attending: attending,
      open: true,
      started: false,
      cancelled: false,
      joinable: false,
      ended: false,
      rsvpUrl: '/rsvp/$slug',
      joinUrl: null,
      subscribeUrl: '/subscribe/$slug',
      calLink: '/calendar/$slug',
      subscribed: true,
      userTimezone: 'UTC',
      meetingProvider: MeetingProviderEnum.livekit,
    );
