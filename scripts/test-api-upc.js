// node scripts/test-api-upc.js — unit checks for api/upc.js (no network).
const assert = require('assert');
const handler = require('../api/upc.js');
const { validCheckDigit } = handler;

for (const ok of ['012993441012', '012345678905', '4006381333931', '96385074', '04252614', '00012345600012', '12993441012'])
  assert.ok(validCheckDigit(ok), `should be valid: ${ok}`);
for (const bad of ['882224514391', '012993441013', '4006381333932', '96385075'])
  assert.ok(!validCheckDigit(bad), `should be invalid: ${bad}`);

function call(upc, upstream) {
  let calls = 0;
  global.fetch = async () => { calls++; return upstream; };
  const res = { headers: {}, setHeader(k, v) { this.headers[k] = v; }, end(b) { this.body = JSON.parse(b); } };
  return handler({ method: 'GET', query: { upc } }, res).then(() => ({ res, calls }));
}

(async () => {
  let { res, calls } = await call('882224514391', null);
  assert.strictEqual(res.statusCode, 400);
  assert.strictEqual(res.body.error, 'invalid_upc');
  assert.strictEqual(calls, 0, 'bad check digit must not hit upstream');
  assert.match(res.headers['Cache-Control'], /s-maxage=86400/);

  ({ res } = await call('012993441012', { status: 400, ok: false, headers: { get: () => null } }));
  assert.strictEqual(res.statusCode, 400);
  assert.strictEqual(res.body.error, 'invalid_upc');

  ({ res } = await call('012993441012', { status: 429, ok: false, headers: { get: () => '30' } }));
  assert.strictEqual(res.statusCode, 429);

  ({ res } = await call('012993441012', { status: 500, ok: false, headers: { get: () => null } }));
  assert.strictEqual(res.statusCode, 502);

  ({ res } = await call('012993441012', { status: 200, ok: true, json: async () => ({ items: [{ title: 'LaCroix' }] }) }));
  assert.strictEqual(res.statusCode, 200);
  console.log('api/upc tests: all passed');
})().catch((e) => { console.error(e); process.exit(1); });
