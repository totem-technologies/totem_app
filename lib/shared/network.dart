import 'package:totem_app/core/config/app_config.dart';

String getFullUrl(String url) {
  if (url.isEmpty) {
    return '';
  }

  // Check if URL is already fully qualified
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  // Ensure the URL and base path are properly joined
  final baseUrl = AppConfig.apiUrl;
  // Remove trailing slash from base URL if any
  final normalizedBaseUrl =
      baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
  // Ensure url starts with a slash
  final normalizedUrl = url.startsWith('/') ? url : '/$url';

  return '$normalizedBaseUrl$normalizedUrl';
}
