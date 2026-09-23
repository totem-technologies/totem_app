import 'package:totem_web/core/navigation/browser_environment_stub.dart'
    if (dart.library.js_interop) 'browser_environment_web.dart'
    as platform;

/// Browser effects used by navigation, separate from route configuration.
abstract interface class BrowserEnvironment {
  factory BrowserEnvironment() => platform.createBrowserEnvironment();

  Uri get currentUri;

  void setDocumentTitle(String title);

  void setTabCloseConfirmationEnabled(bool enabled);
}
