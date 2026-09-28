import 'dart:io';

void main() async {
  final staticDir = Directory('build/web');
  if (!staticDir.existsSync()) {
    stderr.writeln('build/web directory not found. Run flutter build web first.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  stdout.writeln('FlipBin Web Server listening at http://localhost:8080');

  await for (final request in server) {
    var path = request.uri.path;
    if (path == '/' || path.isEmpty) {
      path = '/index.html';
    }

    var file = File('${staticDir.path}$path');
    if (!file.existsSync()) {
      // SPA client-side routing fallback
      file = File('${staticDir.path}/index.html');
    }

    final ext = file.path.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'html' => ContentType.html,
      'js' => ContentType('application', 'javascript', charset: 'utf-8'),
      'css' => ContentType('text', 'css', charset: 'utf-8'),
      'json' => ContentType.json,
      'png' => ContentType('image', 'png'),
      'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
      'wasm' => ContentType('application', 'wasm'),
      'otf' || 'ttf' => ContentType('font', 'otf'),
      _ => ContentType.binary,
    };

    request.response.headers.contentType = contentType;
    // Add CORS and disable caching headers for local testing
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');
    request.response.headers.add('Pragma', 'no-cache');
    request.response.headers.add('Expires', '0');
    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}
