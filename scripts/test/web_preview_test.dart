import 'package:flutter_test/flutter_test.dart';

import '../web_preview.dart';

void main() {
  test('preview aliases are unique DNS labels for unusual branches', () {
    expect(
      previewAlias('163', 'bruno/Direct Messages'),
      'pr-163-bruno-direct-messages',
    );
    expect(previewAlias('1', '💬'), 'pr-1-preview');
    expect(
      '${previewAlias('12', 'a/' * 100)}-totem-web-preview',
      matches(RegExp(r'^[a-z][a-z0-9-]{0,61}[a-z0-9]$')),
    );
    expect(previewAlias('1', 'same'), isNot(previewAlias('2', 'same')));
    expect('${previewAlias('12', 'a' * 100)}-totem-web-preview'.length, 63);
    for (final number in ['../production', '0', '-1', '1.5', '']) {
      expect(() => previewAlias(number, 'branch'), throwsArgumentError);
    }
  });

  test('CI outputs select the same deployment on staging and the CDN', () {
    final outputs = previewOutputs('166', 'video-experience\nurl=evil');
    expect(outputs.keys, unorderedEquals(['alias', 'asset_base', 'url']));
    expect(outputs['alias'], 'pr-166-video-experience-url-evil');
    expect(
      outputs['asset_base'],
      'https://${outputs['alias']}-totem-web-preview.lopkerk.workers.dev/',
    );
    final url = Uri.parse(outputs['url']!);
    expect(url.origin, 'https://totem.kbl.io');
    expect(url.path, '/');
    expect(url.queryParameters, {'room_preview': outputs['alias']});
    expect(outputs.values.every((value) => !value.contains('\n')), isTrue);
  });

  test('only the current open PR commit may deploy', () {
    expect(previewStatus('open', 'latest', 'latest'), {'deploy': 'true'});
    expect(previewStatus('open', 'latest', 'old')['deploy'], 'false');
    expect(previewStatus('closed', 'latest', 'latest'), {'deploy': 'false'});
  });
}
