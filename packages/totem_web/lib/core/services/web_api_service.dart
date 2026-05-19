import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:web/web.dart' as web;

final webApiServiceProvider = Provider<ClientApi>((ref) {
  return ClientApi(
    ApiConfig(
      client: BrowserCredentialedApiClient(
        baseUrl: Uri.parse(AppConfig.apiBaseUrl),
        inner: BrowserClient()..withCredentials = true,
      ),
    ),
  );
}, name: 'Web Totem API Service Provider');

final class BrowserCredentialedApiClient implements ApiClient {
  BrowserCredentialedApiClient({required this.baseUrl, http.Client? inner})
    : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  final Uri baseUrl;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final uri = request.resolveUri(baseUrl);
    final cancelToken = request.options?.cancelToken;
    if (cancelToken?.isCancelled ?? false) {
      throw const CancelledException();
    }

    final abortTrigger = cancelToken?.whenCancelled;

    if (request.body is List<ApiMultipartField>) {
      final multipart = http.AbortableMultipartRequest(
        request.method,
        uri,
        abortTrigger: abortTrigger,
      )..headers.addAll(request.resolvedHeaders());

      for (final field in request.body! as List<ApiMultipartField>) {
        switch (field) {
          case ApiMultipartTextField():
            multipart.fields[field.name] = field.value;
          case ApiMultipartFileField():
            multipart.files.add(
              http.MultipartFile.fromBytes(
                field.name,
                field.bytes,
                filename: field.filename ?? field.name,
                contentType: field.contentType != null
                    ? http.MediaType.parse(field.contentType!)
                    : null,
              ),
            );
        }
      }

      return _send(multipart);
    }

    final httpRequest = http.AbortableRequest(
      request.method,
      uri,
      abortTrigger: abortTrigger,
    )..headers.addAll(_resolvedHeaders(request));

    if (request.contentType != null) {
      httpRequest.headers['content-type'] = request.contentType!;
    }

    if (request.body != null) {
      final body = request.body;
      if (body is String) {
        httpRequest.body = body;
      } else if (body is List<int>) {
        httpRequest.bodyBytes = body;
      } else {
        throw UnsupportedError(
          'BrowserCredentialedApiClient only supports String, List<int>, and '
          'List<ApiMultipartField> request bodies.',
        );
      }
    }

    return _send(httpRequest);
  }

  Future<ApiResponse> _send(http.BaseRequest request) async {
    try {
      final streamed = await _inner.send(request);
      final bytes = await streamed.stream.toBytes();
      return ApiResponse(
        statusCode: streamed.statusCode,
        headers: streamed.headers,
        body: utf8.decode(bytes, allowMalformed: true),
        bodyBytes: bytes,
      );
    } on http.RequestAbortedException {
      throw const CancelledException();
    }
  }

  @override
  Future<StreamedApiResponse> sendStreaming(ApiRequest request) async {
    final uri = request.resolveUri(baseUrl);
    final cancelToken = request.options?.cancelToken;
    if (cancelToken?.isCancelled ?? false) {
      throw const CancelledException();
    }

    final httpRequest = http.AbortableRequest(
      request.method,
      uri,
      abortTrigger: cancelToken?.whenCancelled,
    )..headers.addAll(_resolvedHeaders(request));

    if (request.contentType != null) {
      httpRequest.headers['content-type'] = request.contentType!;
    }

    if (request.body != null) {
      final body = request.body;
      if (body is String) {
        httpRequest.body = body;
      } else if (body is List<int>) {
        httpRequest.bodyBytes = body;
      }
    }

    try {
      final streamed = await _inner.send(httpRequest);
      return StreamedApiResponse(
        statusCode: streamed.statusCode,
        headers: streamed.headers,
        byteStream: streamed.stream,
      );
    } on http.RequestAbortedException {
      throw const CancelledException();
    }
  }

  @override
  Future<void> close() async {
    _inner.close();
  }

  Map<String, String> _resolvedHeaders(ApiRequest request) {
    final headers = <String, String>{
      ...request.resolvedHeaders(),
      'X-Requested-With': 'XMLHttpRequest',
    };

    final csrfToken = _readCookieValue('csrftoken');
    if (csrfToken != null && csrfToken.isNotEmpty) {
      headers['X-CSRFToken'] = csrfToken;
    }

    return headers;
  }
}

String? _readCookieValue(String cookieName) {
  final cookie = web.document.cookie;
  if (cookie.isEmpty) {
    return null;
  }

  for (final part in cookie.split(';')) {
    final trimmed = part.trim();
    if (trimmed.startsWith('$cookieName=')) {
      return Uri.decodeComponent(trimmed.substring(cookieName.length + 1));
    }
  }

  return null;
}
