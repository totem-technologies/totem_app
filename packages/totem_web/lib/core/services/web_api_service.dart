import 'package:degenerate_dio/degenerate_dio.dart';
import 'package:dio/browser.dart';
import 'package:dio/dio.dart' hide Interceptor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/client/api_client_api.dart';
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
  )..httpClientAdapter = (BrowserHttpClientAdapter()..withCredentials = true);

  return ClientApi(
    ApiConfig(
      client: DioApiClient(
        baseUrl: Uri.parse(AppConfig.apiBaseUrl),
        inner: dio,
      ),
      interceptors: [_CsrfInterceptor()],
    ),
  );
}, name: 'Web Totem API Service Provider');

const _unsafeMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

class _CsrfInterceptor implements Interceptor {
  @override
  Future<ApiResponse> intercept(ApiRequest req, Handler next) async {
    if (!_unsafeMethods.contains(req.method.toUpperCase())) return next(req);
    final token = _readCookie('csrftoken');
    if (token == null) return next(req);
    return next(req.copyWith(headers: {...req.headers, 'X-CSRFToken': token}));
  }
}

String? _readCookie(String name) {
  for (final part in web.document.cookie.split(';')) {
    final t = part.trim();
    if (t.startsWith('$name=')) {
      return Uri.decodeComponent(t.substring(name.length + 1));
    }
  }
  return null;
}
