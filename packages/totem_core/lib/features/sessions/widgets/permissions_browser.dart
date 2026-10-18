import 'package:totem_core/features/sessions/widgets/permissions_browser_stub.dart'
    if (dart.library.js_interop) 'package:totem_core/features/sessions/widgets/permissions_browser_web.dart'
    as platform;

String get permissionsBrowserUserAgent => platform.permissionsBrowserUserAgent;
