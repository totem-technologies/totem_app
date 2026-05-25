import 'package:degenerate_dio/degenerate_dio.dart';
import 'package:dio/browser.dart';
import 'package:dio/dio.dart' hide Interceptor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/client/api_client_api.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_web/auth/controllers/auth_controller.dart';

final webApiServiceProvider = Provider<ClientApi>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  )..httpClientAdapter = (BrowserHttpClientAdapter()..withCredentials = true);

  addSharedApiInterceptors(dio);

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
    final token = WebAuthController.readCookieValue('csrftoken');
    if (token == null) return next(req);
    return next(req.copyWith(headers: {...req.headers, 'X-CSRFToken': token}));
  }
}
