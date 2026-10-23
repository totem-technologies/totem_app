import 'package:web/web.dart' as web;

String get webUserAgent => web.window.navigator.userAgent;

int get webMaxTouchPoints => web.window.navigator.maxTouchPoints;
