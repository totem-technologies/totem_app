// Static file server for local web testing.
//
// Serves the built Flutter web bundle (packages/totem_web/build/web) with the
// headers the assets need when the HTML document is served from a *different*
// origin than the assets -- which is the production topology this project
// targets: Django serves the /room/ HTML, and the assets are fetched from a CDN
// via ASSET_BASE. Locally that means e.g. Django at http://localhost:8000 and
// this server (the "CDN") at http://localhost:5173.
//
// A plain static server sends no CORS headers, so those cross-origin asset
// fetches get blocked. This adds:
//
//   - Access-Control-Allow-Origin: *             so the document origin may fetch assets
//   - Cross-Origin-Resource-Policy: cross-origin  so a COEP-isolated page may embed them
//
// Usage: dart scripts/serve_web.dart [port] [directory]

// OK to use print
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

// Make sure wasm/js are served with the right MIME type.
final _mimeTypes = <String, ContentType>{
  '.html': ContentType('text', 'html', charset: 'utf-8'),
  '.htm': ContentType('text', 'html', charset: 'utf-8'),
  '.css': ContentType('text', 'css', charset: 'utf-8'),
  '.json': ContentType('application', 'json', charset: 'utf-8'),
  '.js': ContentType('text', 'javascript', charset: 'utf-8'),
  '.mjs': ContentType('text', 'javascript', charset: 'utf-8'),
  '.wasm': ContentType('application', 'wasm'),
  '.png': ContentType('image', 'png'),
  '.jpg': ContentType('image', 'jpeg'),
  '.jpeg': ContentType('image', 'jpeg'),
  '.gif': ContentType('image', 'gif'),
  '.svg': ContentType('image', 'svg+xml'),
  '.ico': ContentType('image', 'x-icon'),
  '.woff': ContentType('font', 'woff'),
  '.woff2': ContentType('font', 'woff2'),
  '.ttf': ContentType('font', 'ttf'),
  '.otf': ContentType('font', 'otf'),
};

ContentType _contentTypeFor(String path) {
  final dot = path.lastIndexOf('.');
  if (dot != -1) {
    final ext = path.substring(dot).toLowerCase();
    final type = _mimeTypes[ext];
    if (type != null) return type;
  }
  return ContentType.binary;
}

void _setCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Cross-Origin-Resource-Policy', 'cross-origin')
    ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
    ..set('Cache-Control', 'no-store');
}

Future<void> _handle(HttpRequest request, Directory root) async {
  final response = request.response;
  _setCorsHeaders(response);

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.noContent;
    await response.close();
    return;
  }

  if (request.method != 'GET' && request.method != 'HEAD') {
    response.statusCode = HttpStatus.methodNotAllowed;
    await response.close();
    return;
  }

  // Resolve the requested path under root, guarding against traversal.
  var relPath = Uri.decodeComponent(request.uri.path);
  if (relPath.endsWith('/')) relPath += 'index.html';
  final normalized = relPath
      .split('/')
      .where((s) => s.isNotEmpty && s != '.' && s != '..')
      .join(Platform.pathSeparator);
  final file = File('${root.path}${Platform.pathSeparator}$normalized');

  if (!await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    response.write('Not Found');
    await response.close();
    return;
  }

  response.statusCode = HttpStatus.ok;
  response.headers.contentType = _contentTypeFor(file.path);

  if (request.method == 'HEAD') {
    response.headers.contentLength = await file.length();
    await response.close();
    return;
  }

  await response.addStream(file.openRead());
  await response.close();
}

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 5173;
  final directory = args.length > 1 ? args[1] : 'packages/totem_web/build/web';
  final root = Directory(directory);

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Serving $directory at http://localhost:$port/ (CORS enabled)');

  ProcessSignal.sigint.watch().listen((_) async {
    print('\nStopped.');
    await server.close(force: true);
    exit(0);
  });

  await for (final request in server) {
    // Don't let one bad request take down the loop.
    unawaited(
      _handle(request, root).catchError((Object _) async {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }),
    );
  }
}
