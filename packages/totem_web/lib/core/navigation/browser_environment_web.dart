import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_environment.dart';

BrowserEnvironment createBrowserEnvironment() => _WebBrowserEnvironment();

/// Set by web/flutter_bootstrap.js before the app loads.
@JS('totemEntrypointBaseUrl')
external String? get _entrypointBaseUrl;

class _WebBrowserEnvironment implements BrowserEnvironment {
  @override
  Uri get currentUri => Uri.base;

  @override
  Uri? get entrypointBaseUri =>
      _entrypointBaseUrl == null ? null : Uri.tryParse(_entrypointBaseUrl!);

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

  @override
  void setPageExitHandler(void Function()? onExit) {
    web.window.onpagehide = onExit == null
        ? null
        : ((web.Event _) => onExit()).toJS;
  }
}
