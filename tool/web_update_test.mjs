import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const source = await readFile(new URL('../web/update.js', import.meta.url), 'utf8');
async function run({ base = 'https://log.example.com/', offline = false, serviceWorker = true, unregisterFails = false, reload = false } = {}) {
  let click;
  let destination;
  const removed = [];
  const fetched = [];
  const button = { disabled: false, addEventListener(_, fn) { click = fn; } };
  const status = { textContent: '' };
  const registration = (scope, script) => ({ scope, active: { scriptURL: script }, unregister: async () => {
    if (unregisterFails) throw new Error('unregister failed');
    removed.push(scope);
  } });
  const registrations = [
    registration(base, base + 'flutter_service_worker.js?v=old'),
    registration(base + 'other/', base + 'other/flutter_service_worker.js'),
    registration(base, base + 'unrelated-service-worker.js'),
  ];
  runInNewContext(source, {
    URL, Date, Error,
    document: { getElementById: (id) => id === 'update' ? button : status },
    window: { location: { href: base + 'update.html' + (reload ? '?reload=123' : ''), replace: (url) => { destination = url; } } },
    navigator: serviceWorker ? { serviceWorker: { getRegistrations: async () => registrations } } : {},
    fetch: async (url, options) => {
      fetched.push(url.pathname);
      if (reload) {
        assert.equal(options.cache, 'reload');
        return { ok: !offline, arrayBuffer: async () => new ArrayBuffer(0) };
      }
      assert.equal(url.pathname, new URL(base).pathname + 'version.json');
      assert.ok(url.searchParams.has('update'));
      assert.equal(options.cache, 'no-store');
      return { ok: !offline, json: async () => ({ version: '2.10.0-R' }) };
    },
    // Accessing data stores would fail the test: none are exposed here.
  });
  if (reload) await new Promise(setImmediate);
  else await click();
  return { removed, destination, button, status, fetched };
}

for (const base of ['https://log.example.com/', 'https://api.example.com/client/']) {
  test('updates only the matching Flutter installation: ' + base, async () => {
    const result = await run({ base });
    assert.deepEqual(result.removed, [base]);
    assert.equal(new URL(result.destination).pathname, new URL(base).pathname + 'update.html');
    assert.ok(new URL(result.destination).searchParams.has('reload'));
    assert.match(result.status.textContent, /2\.10\.0-R/);
  });
}
test('offline failure keeps worker and does not navigate', async () => {
  const result = await run({ offline: true });
  assert.deepEqual(result.removed, []);
  assert.equal(result.destination, undefined);
  assert.equal(result.button.disabled, false);
});
test('unregister failure permits retry without navigating', async () => {
  const result = await run({ unregisterFails: true });
  assert.equal(result.destination, undefined);
  assert.equal(result.button.disabled, false);
});
test('works without service worker support', async () => {
  const result = await run({ serviceWorker: false });
  assert.ok(result.destination);
});
test('uncontrolled recovery page refreshes HTTP code cache before returning to app', async () => {
  const result = await run({ reload: true, base: 'https://api.example.com/client/' });
  assert.equal(result.fetched.length, 5);
  assert.ok(result.fetched.every((pathname) => pathname.startsWith('/client/')));
  assert.equal(new URL(result.destination).pathname, '/client/');
  assert.ok(new URL(result.destination).searchParams.has('updated'));
  assert.deepEqual(result.removed, []);
});
test('failed code download stays on recovery page and allows retry', async () => {
  const result = await run({ reload: true, offline: true });
  assert.equal(result.destination, undefined);
  assert.equal(result.button.disabled, false);
});
