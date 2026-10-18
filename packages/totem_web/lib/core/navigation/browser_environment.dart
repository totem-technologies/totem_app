import 'browser_environment_stub.dart'
    if (dart.library.js_interop) 'browser_environment_web.dart'
    as platform;

/// Browser effects used by navigation, separate from route configuration.
abstract interface class BrowserEnvironment {
  factory BrowserEnvironment() => platform.createBrowserEnvironment();

  Uri get currentUri;

  /// The URL flutter_bootstrap.js loaded main.dart.js (or .wasm) from, or
  /// null outside a bootstrapped page. Deployed builds load from ASSET_BASE,
  /// not from [currentUri].
  Uri? get entrypointBaseUri;

  void setDocumentTitle(String title);

  void setTabCloseConfirmationEnabled(bool enabled);

  /// Runs [onExit] on `pagehide`, once the page is actually unloading. That
  /// is after the user confirms any tab-close prompt; cancelling it does not
  /// call [onExit]. Null removes the handler.
  ///
  /// `pagehide` also fires when the browser keeps the page in its
  /// back/forward cache. Leaving the call is still right then: the user has
  /// navigated away, and pages with live WebRTC connections are generally
  /// not cached anyway.
  void setPageExitHandler(void Function()? onExit);
}
