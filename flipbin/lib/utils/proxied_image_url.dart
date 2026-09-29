import 'package:flutter/foundation.dart' show kIsWeb;

/// Rewrites remote cover URLs through same-origin `/api/image` on web.
///
/// Flutter web CanvasKit fetches image bytes via XHR/fetch, which requires
/// CORS. Many product CDNs (e.g. covers*.booksamillion.com) omit
/// Access-Control-Allow-Origin, so [Image.network] fails. Same-origin proxy
/// bytes load fine. Native platforms load remote URLs directly.
String? proxiedImageUrl(String? url, {String? origin, bool? forceWeb}) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  final onWeb = forceWeb ?? kIsWeb;
  if (!onWeb) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;

  // Already a proxy path (relative or absolute).
  if (uri.path == '/api/image' || uri.path.endsWith('/api/image')) {
    if (!uri.hasScheme) {
      final base = origin ?? (kIsWeb ? Uri.base.origin : '');
      if (base.isEmpty) return trimmed;
      return '$base$trimmed';
    }
    return trimmed;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return trimmed;
  }

  // Upgrade mixed-content http covers when building the proxy target.
  var target = trimmed;
  if (uri.scheme == 'http') {
    target = 'https://${trimmed.substring('http://'.length)}';
  }

  final base = origin ?? (kIsWeb ? Uri.base.origin : '');
  final qs = 'url=${Uri.encodeQueryComponent(target)}';
  if (base.isEmpty) {
    return '/api/image?$qs';
  }
  return '$base/api/image?$qs';
}
