import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:degenerate_runtime/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

import '../../setup.dart';

void main() {
  setupAppConfig();

  test('registers and unregisters an installation using its FID', () async {
    final client = RecordingClient(
      onRequest: (request) => ApiResponse(
        statusCode: 200,
        body: request.method == 'POST'
            ? jsonEncode({
                'fid': 'installation/id',
                'active': true,
                'created_at': '2026-01-01T00:00:00Z',
              })
            : '',
      ),
    );
    final repository = AuthRepository(
      apiService: ClientApi(ApiConfig(client: client)),
    );

    await repository.registerFid('installation/id');
    await repository.unregisterFid('installation/id');

    check(client.requests).length.equals(2);
    check(client.requests[0].method).equals('POST');
    check(client.requests[0].path).equals('/api/mobile/protected/fcm/register');
    check(
      jsonDecode(client.requests[0].body! as String) as Map<String, dynamic>,
    ).deepEquals({'fid': 'installation/id'});
    check(client.requests[1].method).equals('DELETE');
    check(
      client.requests[1].path,
    ).equals('/api/mobile/protected/fcm/unregister/installation%2Fid');
  });
}
