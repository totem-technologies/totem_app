import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_environment.dart';

BrowserEnvironment createBrowserEnvironment() => _WebBrowserEnvironment();

class _WebBrowserEnvironment implements BrowserEnvironment {
  @override
  Uri get currentUri => Uri.base;

  @override
  void setDocumentTitle(String title) {
    web.document.title = title;
  }

  static void _beforeUnloadListener(web.Event event) {
    final beforeUnloadEvent = event as web.BeforeUnloadEvent;
    beforeUnloadEvent.returnValue = 'Are you sure you want to leave?';
  }

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {
    web.window.onbeforeunload = enabled ? _beforeUnloadListener.toJS : null;
  }
}
