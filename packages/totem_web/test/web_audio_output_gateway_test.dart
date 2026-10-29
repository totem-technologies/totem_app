import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/web_audio_output_router.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'applies the selected output when LiveKit creates its first audio element',
    () async {
      final gateway = createWebAudioOutputGateway();
      final container = web.document.createElement('div') as web.HTMLDivElement;
      final audio = web.document.createElement('audio') as web.HTMLAudioElement;
      final sinkApplied = Completer<String>();
      audio.setProperty(
        'setSinkId'.toJS,
        ((JSAny? sinkId) {
          sinkApplied.complete((sinkId! as JSString).toDart);
          return Future<JSAny?>.value().toJS;
        }).toJS,
      );
      addTearDown(() async {
        await gateway.stop();
        container.remove();
      });

      await gateway.start();
      await gateway.setSinkId('headphones');

      container
        ..id = 'livekit_audio_container'
        ..append(audio);
      web.document.body!.append(container);

      check(await sinkApplied.future).equals('headphones');
    },
    timeout: const Timeout(Duration(seconds: 1)),
  );
}
