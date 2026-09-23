import 'dart:js_interop';

import 'package:totem_web/core/navigation/browser_environment.dart';
import 'package:web/web.dart' as web;

BrowserEnvironment createBrowserEnvironment() => _WebBrowserEnvironment();

class _WebBrowserEnvironment implements BrowserEnvironment {
  @override
  Uri get currentUri => Uri.base;

  @override
  void setDocumentTitle(String title) {
    web.document.title = title;
  }

  static void _beforeUnloadListener(web.Event event) {
    final _ = event as web.BeforeUnloadEvent
      ..returnValue = 'Are you sure you want to leave?';
  }

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {
    web.window.onbeforeunload = enabled ? _beforeUnloadListener.toJS : null;
  }
}
