import 'package:flutter/foundation.dart' show kIsWeb;

/// Normalizes a product cover URL for [Image.network].
///
/// - Upgrades `http://` → `https://` to avoid mixed-content blocks on web.
/// - Leaves https / relative / already-proxied URLs alone.
///
/// Flutter web CanvasKit fetches image *bytes* and requires CORS. Many cover
/// CDNs omit `Access-Control-Allow-Origin`, so callers should also set
/// `webHtmlElementStrategy: WebHtmlElementStrategy.prefer` so the browser
/// `<img>` path can display the cover without CORS. Do **not** force covers
/// through `/api/image` — some CDNs (Cloudflare) block Vercel egress with 403.
String? proxiedImageUrl(String? url, {String? origin, bool? forceWeb}) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;

  // Mixed content: upgrade http covers to https.
  if (uri.scheme == 'http') {
    return 'https://${trimmed.substring('http://'.length)}';
  }

  // origin / forceWeb kept for call-site compatibility / tests.
  // ignore: unused_local_variable
  final _ = (origin, forceWeb ?? kIsWeb);
  return trimmed;
}
