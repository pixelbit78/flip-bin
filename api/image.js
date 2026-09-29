/**
 * Serverless image proxy: GET /api/image?url=https://...
 * Same-origin bytes so Flutter web CanvasKit Image.network can display
 * cover art from CDNs that omit Access-Control-Allow-Origin.
 */
const MAX_BYTES = 5 * 1024 * 1024; // 5 MiB
const FETCH_MS = 10000;

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(res, status, body) {
  setCors(res);
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(body));
}

function isPrivateHost(hostname) {
  const h = String(hostname || '').toLowerCase();
  if (!h) return true;
  if (h === 'localhost' || h.endsWith('.localhost') || h === '0.0.0.0') return true;
  if (h === 'metadata.google.internal') return true;
  // IPv4 private / loopback / link-local
  const m = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(h);
  if (m) {
    const a = +m[1];
    const b = +m[2];
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
  }
  // Obvious IPv6 locals
  if (h === '::1' || h.startsWith('fc') || h.startsWith('fd') || h.startsWith('fe80')) return true;
  return false;
}

function normalizeTarget(raw) {
  if (raw == null) return null;
  let s = String(raw).trim();
  if (!s) return null;
  // Mixed content / legacy http cover links → https
  if (s.startsWith('http://')) {
    s = `https://${s.slice('http://'.length)}`;
  }
  let u;
  try {
    u = new URL(s);
  } catch {
    return null;
  }
  if (u.protocol !== 'https:') return null;
  if (isPrivateHost(u.hostname)) return null;
  return u.toString();
}

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    setCors(res);
    res.statusCode = 204;
    res.end();
    return;
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    sendJson(res, 405, { error: 'method_not_allowed' });
    return;
  }

  const target = normalizeTarget(req.query && req.query.url);
  if (!target) {
    sendJson(res, 400, {
      error: 'invalid_url',
      message: 'Query parameter url must be a public https URL',
    });
    return;
  }

  try {
    const upstream = await fetch(target, {
      method: 'GET',
      redirect: 'follow',
      headers: {
        Accept: 'image/*,*/*;q=0.8',
        'User-Agent': 'FlipBin/1.0 (https://github.com/pixelbit78/flip-bin)',
      },
      signal: AbortSignal.timeout(FETCH_MS),
    });

    if (!upstream.ok) {
      sendJson(res, 502, {
        error: 'upstream_error',
        status: upstream.status,
      });
      return;
    }

    const contentType = (upstream.headers.get('content-type') || '').toLowerCase();
    if (contentType && !contentType.startsWith('image/') && !contentType.startsWith('application/octet-stream')) {
      sendJson(res, 502, {
        error: 'not_an_image',
        contentType,
      });
      return;
    }

    const buf = Buffer.from(await upstream.arrayBuffer());
    if (buf.length === 0 || buf.length > MAX_BYTES) {
      sendJson(res, 502, {
        error: buf.length === 0 ? 'empty_image' : 'image_too_large',
        bytes: buf.length,
      });
      return;
    }

    setCors(res);
    res.statusCode = 200;
    res.setHeader('Content-Type', contentType || 'image/jpeg');
    res.setHeader('Cache-Control', 'public, max-age=86400, stale-while-revalidate=604800');
    res.setHeader('Content-Length', String(buf.length));
    if (req.method === 'HEAD') {
      res.end();
      return;
    }
    res.end(buf);
  } catch (err) {
    const message = err && err.name === 'TimeoutError' ? 'upstream_timeout' : 'upstream_fetch_failed';
    sendJson(res, 502, { error: message });
  }
};
