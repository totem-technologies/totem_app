import 'dart:js_interop';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_web/core/reload_prompt.dart';
import 'package:web/web.dart' as web;

void main() {
  tearDown(() {
    web.document.getElementById(reloadPromptElementId)?.remove();
    web.window.onbeforeunload = null;
  });

  test('adds a single overlay to the document', () {
    showReloadPrompt(reload: () {});
    showReloadPrompt(reload: () {});

    final overlays = web.document.querySelectorAll('#$reloadPromptElementId');
    check(overlays.length).equals(1);
    check(overlays.item(0)!.textContent ?? '').contains('Reload');
  });

  test('reloads without the leave-page confirmation', () {
    var reloads = 0;
    web.window.onbeforeunload = ((web.Event _) {}).toJS;
    showReloadPrompt(reload: () => reloads++);

    final button =
        web.document.querySelector('#$reloadPromptElementId button')!
            as web.HTMLButtonElement;
    button.click();

    check(reloads).equals(1);
    check(web.window.onbeforeunload).isNull();
  });
}
