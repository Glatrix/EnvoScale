// The client's framing: messages split across chunks, several in one chunk, and bodies
// counted in bytes, not characters.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { Framer, frame } = require('../lsp');

test('a message split across chunks arrives whole', () => {
  const got = [];
  const f = new Framer((m) => got.push(m));
  const bytes = frame({ jsonrpc: '2.0', id: 1, result: { text: 'héllo → world' } });
  for (let i = 0; i < bytes.length; i += 7) f.push(bytes.subarray(i, i + 7));
  assert.deepStrictEqual(got, [{ jsonrpc: '2.0', id: 1, result: { text: 'héllo → world' } }]);
});

test('several messages in one chunk arrive in order', () => {
  const got = [];
  const f = new Framer((m) => got.push(m.id));
  f.push(Buffer.concat([frame({ id: 1 }), frame({ id: 2 }), frame({ id: 3 })]));
  assert.deepStrictEqual(got, [1, 2, 3]);
});

test('Content-Length counts bytes', () => {
  const bytes = frame({ s: 'é' });
  const head = bytes.toString('ascii').split('\r\n')[0];
  assert.strictEqual(head, `Content-Length: ${Buffer.byteLength(JSON.stringify({ s: 'é' }), 'utf8')}`);
});

test('a body that does not parse is reported and skipped', () => {
  const got = [];
  const errors = [];
  const f = new Framer((m) => got.push(m), (e) => errors.push(e));
  f.push(Buffer.from('Content-Length: 3\r\n\r\n{x}', 'ascii'));
  f.push(frame({ ok: true }));
  assert.strictEqual(errors.length, 1);
  assert.deepStrictEqual(got, [{ ok: true }]);
});
