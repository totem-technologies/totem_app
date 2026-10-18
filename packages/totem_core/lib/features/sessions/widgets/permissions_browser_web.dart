import 'dart:js_interop';

@JS('navigator.userAgent')
external String get _userAgent;

String get permissionsBrowserUserAgent => _userAgent;
