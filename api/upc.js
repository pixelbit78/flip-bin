/**
 * Serverless proxy: GET /api/upc?upc=...
 * Calls UPCitemdb trial server-side (avoids browser CORS) and returns clean JSON.
 * Cover imageUrl is rewritten through /api/image so Flutter web CanvasKit can load it.
 */
const UPSTREAM = 'https://api.upcitemdb.com/prod/trial/lookup';

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 'public, max-age=300');
}

function json(res, status, body) {
  setCors(res);
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(body));
}

function normalizeUpc(raw) {
  if (raw == null) return '';
  return String(raw).trim();
}

/** Prefer first images[] entry; upgrade http→https. */
function pickImage(item) {
  const images = item && item.images;
  if (Array.isArray(images) && images.length > 0 && images[0]) {
    let url = String(images[0]).trim();
    if (!url) return null;
    if (url.startsWith('http://')) {
      url = `https://${url.slice('http://'.length)}`;
    }
    return url;
  }
  return null;
}

/**
 * Same-origin image proxy URL so CanvasKit Image.network is not blocked by
 * CDNs that omit Access-Control-Allow-Origin (e.g. covers*.booksamillion.com).
 */
function toProxiedImageUrl(req, rawUrl) {
  if (!rawUrl) return null;
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  const proto = req.headers['x-forwarded-proto'] || 'https';
  const qs = `url=${encodeURIComponent(rawUrl)}`;
  if (!host) {
    return `/api/image?${qs}`;
  }
  return `${proto}://${host}/api/image?${qs}`;
}

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    setCors(res);
    res.statusCode = 204;
    res.end();
    return;
  }

  if (req.method !== 'GET') {
    json(res, 405, { error: 'method_not_allowed' });
    return;
  }

  const upc = normalizeUpc(req.query && req.query.upc);
  if (!upc) {
    json(res, 400, { error: 'missing_upc', message: 'Query parameter upc is required' });
    return;
  }
  // Keep digits (and leading zeros) — UPCitemdb expects the UPC string as scanned.
  if (!/^\d{8,14}$/.test(upc)) {
    json(res, 400, {
      error: 'invalid_upc',
      barcode: upc,
      message: 'upc must be 8–14 digits',
    });
    return;
  }

  try {
    const url = `${UPSTREAM}?upc=${encodeURIComponent(upc)}`;
    const upstream = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'User-Agent': 'FlipBin/1.0 (https://github.com/pixelbit78/flip-bin)',
      },
      // Trial API is rate-limited; fail fast.
      signal: AbortSignal.timeout(8000),
    });

    if (upstream.status === 404) {
      json(res, 404, { error: 'not_found', barcode: upc });
      return;
    }

    if (!upstream.ok) {
      json(res, 502, {
        error: 'upstream_error',
        barcode: upc,
        status: upstream.status,
      });
      return;
    }

    const data = await upstream.json();
    const items = data && Array.isArray(data.items) ? data.items : [];
    if (items.length === 0) {
      json(res, 404, { error: 'not_found', barcode: upc });
      return;
    }

    const item = items[0] || {};
    const productName = (item.title || item.name || '').toString().trim();
    if (!productName) {
      json(res, 404, { error: 'not_found', barcode: upc });
      return;
    }

    const rawImage = pickImage(item);

    json(res, 200, {
      barcode: upc,
      productName,
      description: item.description != null ? String(item.description) : null,
      imageUrl: toProxiedImageUrl(req, rawImage),
      category: item.category != null ? String(item.category) : null,
      source: 'UPCitemdb',
    });
  } catch (err) {
    const message = err && err.name === 'TimeoutError' ? 'upstream_timeout' : 'upstream_fetch_failed';
    json(res, 502, {
      error: message,
      barcode: upc,
    });
  }
};
