import 'dart:convert';
import 'dart:io';

const previewWorkerName = 'totem-web-preview';

String previewAlias(String number, String branch) {
  final parsedNumber = int.tryParse(number);
  if (parsedNumber == null || parsedNumber < 1) {
    throw ArgumentError('Expected a positive PR number');
  }
  final prefix = 'pr-$parsedNumber-';
  var slug = branch
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  if (slug.isEmpty) slug = 'preview';
  final available = 63 - prefix.length - '-$previewWorkerName'.length;
  if (slug.length > available) slug = slug.substring(0, available);
  return '$prefix$slug'.replaceAll(RegExp('-+\$'), '');
}

Map<String, String> previewOutputs(String number, String branch) {
  final alias = previewAlias(number, branch);
  return {
    'alias': alias,
    'asset_base': 'https://$alias-$previewWorkerName.lopkerk.workers.dev/',
    'url': Uri.https('totem.kbl.io', '/', {'preview': alias}).toString(),
  };
}

Map<String, String> previewStatus(
  String state,
  String currentSha,
  String buildSha,
) => {'deploy': '${state == 'open' && currentSha == buildSha}'};

Future<void> main(List<String> args) async {
  try {
    final number = _environment('PR_NUMBER');
    switch (args.isEmpty ? 'address' : args.single) {
      case 'address':
        _writeOutputs(previewOutputs(number, _environment('PR_BRANCH')));
      case 'current':
        final response = await _get(
          Uri.https(
            'api.github.com',
            '/repos/${_environment('GITHUB_REPOSITORY')}/pulls/$number',
          ),
          _environment('GITHUB_TOKEN'),
        );
        if (response.status != HttpStatus.ok) {
          throw HttpException('Reading PR status failed (${response.status})');
        }
        final pr = jsonDecode(response.body) as Map<String, dynamic>;
        final head = pr['head'] as Map<String, dynamic>;
        _writeOutputs(
          previewStatus(
            pr['state'] as String,
            head['sha'] as String,
            _environment('PR_SHA'),
          ),
        );
      default:
        throw ArgumentError(
          'Usage: dart scripts/web_preview.dart [address|current]',
        );
    }
  } catch (error) {
    stderr.writeln('web_preview: $error');
    exitCode = 1;
  }
}

String _environment(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) throw ArgumentError('$key is required');
  return value;
}

void _writeOutputs(Map<String, String> values) {
  File(_environment('GITHUB_OUTPUT')).writeAsStringSync(
    values.entries.map((entry) => '${entry.key}=${entry.value}\n').join(),
    mode: FileMode.append,
  );
}

Future<({int status, String body})> _get(Uri url, String token) async {
  const timeout = Duration(seconds: 30);
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(url).timeout(timeout);
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.userAgentHeader, 'totem-web-preview')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    return (status: response.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}
