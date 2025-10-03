import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

/// (WIP) Script to upload an AAB file to Google Play's internal testing track.
///
/// Usage:
///   dart run scripts/upload_to_play.dart <path-to-aab> <path-to-service-account-json>
///
/// Example:
///   dart run scripts/upload_to_play.dart build/app/outputs/bundle/release/app-release.aab service-account.json
///
/// Prerequisites:
/// 1. Service account JSON key from Google Cloud Console
/// 2. Service account must have "Release Manager" role in Google Play Console
/// 3. AAB file must be built and signed
///
/// Add these dependencies to pubspec.yaml dev_dependencies:
///   googleapis_auth: ^1.6.0
///   http: ^1.2.0

void main(List<String> args) async {
  try {
    await _runUpload(args);
  } catch (e, stackTrace) {
    stderr
      ..writeln('Error: $e')
      ..writeln(stackTrace);
    exit(1);
  }
}

Future<void> _runUpload(List<String> args) async {
  if (args.length < 2) {
    stderr
      ..writeln(
        'Usage: dart run scripts/upload_to_play.dart <aab-file> <service-account-json> [track]',
      )
      ..writeln(
        '  track defaults to "internal" (options: internal, alpha, beta, production)',
      );
    exit(1);
  }

  final aabPath = args[0];
  final serviceAccountPath = args[1];
  final track = args.length > 2 ? args[2] : 'internal';

  // Validate track
  const validTracks = ['internal', 'alpha', 'beta', 'production'];
  if (!validTracks.contains(track)) {
    throw Exception(
      'Invalid track: $track. Must be one of: ${validTracks.join(", ")}',
    );
  }

  // Validate files exist
  final aabFile = File(aabPath);
  if (!aabFile.existsSync()) {
    throw Exception('AAB file not found: $aabPath');
  }

  final serviceAccountFile = File(serviceAccountPath);
  if (!serviceAccountFile.existsSync()) {
    throw Exception('Service account file not found: $serviceAccountPath');
  }

  stdout.writeln('[upload] Reading service account credentials...');
  final credentials = auth.ServiceAccountCredentials.fromJson(
    jsonDecode(serviceAccountFile.readAsStringSync()),
  );

  final packageName = await _getPackageName();
  stdout
    ..writeln('[upload] Package name: $packageName')
    ..writeln('[upload] Authenticating with Google Play...');
  final scopes = ['https://www.googleapis.com/auth/androidpublisher'];
  final httpClient = await auth.clientViaServiceAccount(credentials, scopes);

  try {
    final client = _PlayStoreClient(
      packageName: packageName,
      httpClient: httpClient,
    );

    stdout.writeln('[upload] Creating edit session...');
    final editId = await client.createEdit();
    stdout.writeln('[upload] Edit ID: $editId');

    try {
      stdout.writeln(
        '[upload] Uploading AAB file (${_formatFileSize(aabFile.lengthSync())})...',
      );
      final versionCode = await client.uploadBundle(editId, aabFile);
      stdout
        ..writeln('[upload] Uploaded version code: $versionCode')
        ..writeln('[upload] Assigning to $track track...');
      await client.updateTrack(editId, track, versionCode);

      stdout.writeln('[upload] Committing changes...');
      await client.commitEdit(editId);

      stdout.writeln(
        '[upload] ✓ Success! Version $versionCode uploaded to $track track.',
      );
    } catch (e) {
      stdout.writeln('[upload] Error occurred, rolling back edit...');
      await client.deleteEdit(editId);
      rethrow;
    }
  } finally {
    httpClient.close();
  }
}

Future<String> _getPackageName() async {
  final gradleFile = File('android/app/build.gradle');
  if (!gradleFile.existsSync()) {
    throw Exception('android/app/build.gradle not found');
  }

  final content = gradleFile.readAsStringSync();
  final match = RegExp(r'applicationId\s+"([^"]+)"').firstMatch(content);

  if (match == null) {
    throw Exception('Could not find applicationId in build.gradle');
  }

  return match.group(1)!;
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _PlayStoreClient {
  _PlayStoreClient({
    required this.packageName,
    required this.httpClient,
  });

  final String packageName;
  final http.Client httpClient;

  static const _baseUrl =
      'https://androidpublisher.googleapis.com/androidpublisher/v3';

  Future<String> createEdit() async {
    final response = await httpClient.post(
      Uri.parse('$_baseUrl/applications/$packageName/edits'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create edit: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    return data['id'] as String;
  }

  Future<int> uploadBundle(String editId, File aabFile) async {
    final bytes = aabFile.readAsBytesSync();

    final response = await httpClient.post(
      Uri.parse('$_baseUrl/applications/$packageName/edits/$editId/bundles'),
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': bytes.length.toString(),
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to upload bundle: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    return data['versionCode'] as int;
  }

  Future<void> updateTrack(String editId, String track, int versionCode) async {
    final body = jsonEncode({
      'track': track,
      'releases': [
        {
          'versionCodes': [versionCode.toString()],
          'status': 'completed',
        },
      ],
    });

    final response = await httpClient.put(
      Uri.parse(
        '$_baseUrl/applications/$packageName/edits/$editId/tracks/$track',
      ),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update track: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> commitEdit(String editId) async {
    final response = await httpClient.post(
      Uri.parse('$_baseUrl/applications/$packageName/edits/$editId:commit'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to commit edit: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> deleteEdit(String editId) async {
    await httpClient.delete(
      Uri.parse('$_baseUrl/applications/$packageName/edits/$editId'),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
