import 'package:degenerate_dio/degenerate_dio.dart';
import 'package:dio/browser.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:web/web.dart' as web;

final webApiServiceProvider = Provider<ClientApi>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // Use browser adapter and enable credentials so cookies are sent.
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;

  // Inject CSRF token from cookie and mark AJAX requests.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Requested-With'] = 'XMLHttpRequest';
        final csrf = _readCookieValue('csrftoken');
        if (csrf != null && csrf.isNotEmpty) {
          options.headers['X-CSRFToken'] = csrf;
        }
        return handler.next(options);
      },
    ),
  );

  return ClientApi(
    ApiConfig(
      client: DioApiClient(
        baseUrl: Uri.parse(AppConfig.apiBaseUrl),
        inner: dio,
      ),
    ),
  );
}, name: 'Web Totem API Service Provider');

String? _readCookieValue(String cookieName) {
  final cookie = web.document.cookie;
  if (cookie.isEmpty) return null;
  for (final part in cookie.split(';')) {
    final trimmed = part.trim();
    if (trimmed.startsWith('$cookieName=')) {
      return Uri.decodeComponent(trimmed.substring(cookieName.length + 1));
    }
  }
  return null;
}
