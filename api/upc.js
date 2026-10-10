/**
 * Serverless proxy: GET /api/upc?upc=...
 * Calls UPCitemdb trial server-side (avoids browser CORS) and returns clean JSON.
 * imageUrl is the first images[] entry, upgraded to https when needed.
 */
const UPSTREAM = 'https://api.upcitemdb.com/prod/trial/lookup';

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 'public, max-age=300');
}

/** Edge-cache definitive answers for a day so repeat scans don't burn the
 * UPCitemdb trial quota (~100/day per IP, burst-limited). */
function cacheDefinitive(res) {
  res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=86400, stale-while-revalidate=604800');
}

function json(res, status, body, cache) {
  setCors(res);
  if (cache) cacheDefinitive(res);
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(body));
}

function normalizeUpc(raw) {
  if (raw == null) return '';
  return String(raw).trim();
}

/** Prefer first images[] entry; upgrade http→https (avoid mixed content). */
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

/** GS1 mod-10 check over a digit string (last digit is the check digit). */
function mod10Ok(code) {
  let sum = 0;
  for (let i = code.length - 2, w = 3; i >= 0; i--, w = 4 - w) {
    sum += Number(code[i]) * w;
  }
  return (10 - (sum % 10)) % 10 === Number(code[code.length - 1]);
}

/** UPC-E (8 digits, number system 0/1) → UPC-A (12 digits). */
function upcEtoA(e) {
  const ns = e[0];
  const d = e.slice(1, 7);
  const chk = e[7];
  const last = d[5];
  let body;
  if ('012'.includes(last)) body = d[0] + d[1] + last + '0000' + d[2] + d[3] + d[4];
  else if (last === '3') body = d[0] + d[1] + d[2] + '00000' + d[3] + d[4];
  else if (last === '4') body = d[0] + d[1] + d[2] + d[3] + '00000' + d[4];
  else body = d[0] + d[1] + d[2] + d[3] + d[4] + '0000' + last;
  return ns + body + chk;
}

/**
 * Check digit validation for EAN-8 / UPC-E / UPC-A / EAN-13 / GTIN-14.
 * 9–11 digit codes (leading zeros dropped) are zero-padded to UPC-A.
 */
function validCheckDigit(code) {
  if (code.length === 8) {
    if (mod10Ok(code)) return true; // EAN-8
    return (code[0] === '0' || code[0] === '1') && mod10Ok(upcEtoA(code));
  }
  return mod10Ok(code.padStart(14, '0'));
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
  if (!/^\d{8,14}$/.test(upc)) {
    json(res, 400, {
      error: 'invalid_upc',
      barcode: upc,
      message: 'upc must be 8–14 digits',
    });
    return;
  }

  if (!validCheckDigit(upc)) {
    json(res, 400, {
      error: 'invalid_upc',
      barcode: upc,
      message: 'check digit does not match',
    }, true);
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
      signal: AbortSignal.timeout(8000),
    });

    if (upstream.status === 429) {
      const retry = upstream.headers.get('retry-after');
      setCors(res);
      res.setHeader('Cache-Control', 'no-store');
      if (retry) res.setHeader('Retry-After', retry);
      res.statusCode = 429;
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.end(JSON.stringify({ error: 'rate_limited', barcode: upc, retryAfter: retry || null }));
      return;
    }

    if (upstream.status === 400) {
      // UPCitemdb answers INVALID_UPC with 400: a client error, not a 502.
      json(res, 400, { error: 'invalid_upc', barcode: upc }, true);
      return;
    }

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

    const ok = {
      barcode: upc,
      productName,
      description: item.description != null ? String(item.description) : null,
      imageUrl: pickImage(item),
      category: item.category != null ? String(item.category) : null,
      source: 'UPCitemdb',
    };
    json(res, 200, ok, true);
  } catch (err) {
    const message = err && err.name === 'TimeoutError' ? 'upstream_timeout' : 'upstream_fetch_failed';
    json(res, 502, {
      error: message,
      barcode: upc,
    });
  }
};

module.exports.validCheckDigit = validCheckDigit;
