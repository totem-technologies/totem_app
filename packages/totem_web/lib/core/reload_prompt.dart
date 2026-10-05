import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

const reloadPromptElementId = 'totem-reload-prompt';

/// Shows a plain DOM overlay asking the user to reload the page.
///
/// This is deliberately not a Flutter widget: it is used when the Flutter
/// engine can no longer render frames, so anything drawn by Flutter would
/// never appear. Calling it again while the overlay is shown does nothing.
void showReloadPrompt({VoidCallback? reload}) {
  final document = web.document;
  if (document.getElementById(reloadPromptElementId) != null) return;

  final button = web.HTMLButtonElement()
    ..type = 'button'
    ..textContent = 'Reload'
    ..style.cssText =
        'margin-top:20px;padding:12px 32px;border:0;border-radius:999px;'
        'background:#000;color:#fff;font:inherit;font-weight:600;'
        'cursor:pointer;';
  button.addEventListener(
    'click',
    ((web.Event _) {
      // The session's leave-page confirmation would otherwise interrupt the
      // reload with a second dialog.
      web.window.onbeforeunload = null;
      if (reload != null) {
        reload();
      } else {
        web.window.location.reload();
      }
    }).toJS,
  );

  final title = web.HTMLHeadingElement.h2()
    ..textContent = 'Something went wrong'
    ..style.cssText = 'margin:0 0 8px;font-size:20px;';
  final message = web.HTMLParagraphElement()
    ..textContent = 'Reload to get back into your session.'
    ..style.cssText = 'margin:0;font-size:16px;line-height:1.4;';

  final card = web.HTMLDivElement()
    ..style.cssText =
        'max-width:340px;padding:28px 24px;border-radius:25px;'
        'background:#fff;color:#000;text-align:center;'
        'box-shadow:0 8px 32px rgba(0,0,0,0.25);';
  card
    ..append(title)
    ..append(message)
    ..append(button);

  final overlay = web.HTMLDivElement()
    ..id = reloadPromptElementId
    ..setAttribute('role', 'alertdialog')
    ..setAttribute('aria-label', 'Reload required')
    ..style.cssText =
        'position:fixed;inset:0;z-index:2147483647;display:flex;'
        'align-items:center;justify-content:center;padding:16px;'
        'background:rgba(0,0,0,0.5);'
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,'
        'sans-serif;';
  overlay.append(card);
  document.body?.append(overlay);
}
