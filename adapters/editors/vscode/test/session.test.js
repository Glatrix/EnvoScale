// The client against the real server: with $ENVO naming the envo program (CI sets it), a
// document with an error gets diagnostics, a fixed one none, and hover, completion,
// definition, symbols and formatting answer. Skipped without $ENVO.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { Client } = require('../lsp');

const envo = process.env.ENVO;
// a document in a folder of its own under the system's temporary folder (the server
// works beside it, in build/envo-lsp), removed afterwards
const os = require('os');
const fsx = require('fs');
const pathx = require('path');
const { pathToFileURL } = require('url');
const folder = fsx.mkdtempSync(pathx.join(os.tmpdir(), 'envo-vscode-'));
const uri = pathToFileURL(pathx.join(folder, 'main.envol')).href;
process.on('exit', () => fsx.rmSync(folder, { recursive: true, force: true }));
const fixed = '// The answer.\ni32 Answer() => 42;\n\nstruct Point {\n    i32 X;\n    i32 Y;\n}\n\nPoint p = new Point { X = 1, Y = 2 };\ni32 v = Answer() + p.X;\n';

test('a session with envo lsp', { skip: !envo && 'set ENVO to the envo program' }, async () => {
  const published = [];
  let wake = null;
  const c = new Client(envo, ['lsp'], {
    onNotification: (method, params) => {
      if (method !== 'textDocument/publishDiagnostics') return;
      published.push(params);
      if (wake) wake();
    },
  });
  const next = () => new Promise((resolve) => { wake = resolve; });
  const caps = await c.start(null);
  assert.ok(caps.hoverProvider && caps.definitionProvider && caps.documentSymbolProvider);

  let got = next();
  c.notify('textDocument/didOpen', { textDocument: { uri, languageId: 'envol', version: 1, text: 'i32 x = ;\n' } });
  await got;
  assert.ok(published[0].diagnostics.length > 0, 'an error is reported');

  got = next();
  c.notify('textDocument/didChange', { textDocument: { uri, version: 2 }, contentChanges: [{ text: fixed }] });
  await got;
  assert.strictEqual(published[published.length - 1].diagnostics.length, 0, 'the fixed text has none');

  const at = (line, character) => ({ textDocument: { uri }, position: { line, character } });
  const hover = await c.request('textDocument/hover', at(9, 10));
  assert.match(hover.contents.value, /The answer\./);
  const def = await c.request('textDocument/definition', at(9, 10));
  assert.strictEqual((Array.isArray(def) ? def[0] : def).range.start.line, 1);
  const comp = await c.request('textDocument/completion', at(9, 21));
  const labels = (Array.isArray(comp) ? comp : comp.items).map((i) => i.label);
  assert.ok(labels.includes('X') && labels.includes('Y'), labels.join(' '));
  const syms = await c.request('textDocument/documentSymbol', { textDocument: { uri } });
  assert.ok(syms.some((s) => s.name === 'Point'));
  const fmt = await c.request('textDocument/formatting', { textDocument: { uri }, options: { tabSize: 4, insertSpaces: true } });
  assert.ok(Array.isArray(fmt));
  await c.stop();
});
