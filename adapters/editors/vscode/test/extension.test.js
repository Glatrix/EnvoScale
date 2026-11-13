// extension.js against a stand-in vscode module: activation registers every provider and
// the restart command; with $ENVO it starts envo lsp, sends an open document, shows the
// diagnostics that come back, and a hover goes through. Skipped without $ENVO past the
// registrations.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const Module = require('module');

const registered = [];
const diagnosticSets = [];
const handlers = {};
const disposable = { dispose() {} };
class Position { constructor(line, character) { Object.assign(this, { line, character }); } }
class Range { constructor(start, end) { Object.assign(this, { start, end }); } }
const fake = {
  Position,
  Range,
  Uri: { parse: (s) => ({ s, toString: () => s }) },
  Diagnostic: class { constructor(range, message, severity) { Object.assign(this, { range, message, severity }); } },
  DiagnosticSeverity: { Error: 0, Warning: 1, Information: 2, Hint: 3 },
  MarkdownString: class { constructor(value) { this.value = value; } },
  Hover: class { constructor(contents, range) { Object.assign(this, { contents, range }); } },
  window: {
    createOutputChannel: () => ({ appendLine() {}, dispose() {} }),
    showWarningMessage: () => {},
  },
  workspace: {
    workspaceFolders: undefined,
    textDocuments: [],
    getConfiguration: () => ({ get: (k) => (k === 'path' ? process.env.ENVO || 'envo-not-installed' : false) }),
    onDidOpenTextDocument: (f) => { handlers.open = f; return disposable; },
    onDidChangeTextDocument: (f) => { handlers.change = f; return disposable; },
    onDidSaveTextDocument: () => disposable,
    onDidCloseTextDocument: () => disposable,
    onDidChangeConfiguration: () => disposable,
  },
  languages: {
    createDiagnosticCollection: () => ({ set: (uri, ds) => diagnosticSets.push([uri, ds]), delete() {}, clear() {}, dispose() {} }),
    registerCompletionItemProvider: (sel, p) => { registered.push('completion'); handlers.completion = p; return disposable; },
    registerHoverProvider: (sel, p) => { registered.push('hover'); handlers.hover = p; return disposable; },
    registerDefinitionProvider: () => { registered.push('definition'); return disposable; },
    registerDocumentSymbolProvider: () => { registered.push('symbols'); return disposable; },
    registerDocumentFormattingEditProvider: () => { registered.push('formatting'); return disposable; },
  },
  commands: { registerCommand: (name) => { registered.push(name); return disposable; } },
};

// require('vscode') inside extension.js gets the stand-in
const resolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
  if (request === 'vscode') return 'vscode';
  return resolve.call(this, request, ...rest);
};
require.cache.vscode = { id: 'vscode', filename: 'vscode', loaded: true, exports: fake };
const ext = require('../extension');

// a document in a folder of its own under the system's temporary folder (the server
// works beside it, in build/envo-lsp), removed afterwards
const os = require('os');
const fsx = require('fs');
const pathx = require('path');
const { pathToFileURL } = require('url');
const folder = fsx.mkdtempSync(pathx.join(os.tmpdir(), 'envo-vscode-'));
const uri = pathToFileURL(pathx.join(folder, 'ext.envol')).href;
process.on('exit', () => fsx.rmSync(folder, { recursive: true, force: true }));
const doc = (text, version) => ({ uri: fake.Uri.parse(uri), languageId: 'envol', version, getText: () => text });

test('activation registers the providers and starts the server', async () => {
  const context = { subscriptions: [] };
  await ext.activate(context);
  assert.deepStrictEqual(registered.sort(), ['completion', 'definition', 'envo.restart', 'formatting', 'hover', 'symbols']);
  if (!process.env.ENVO) {
    await ext.deactivate();
    return;
  }
  handlers.open(doc('i32 x = ;\n', 1));
  for (let i = 0; i < 100 && diagnosticSets.length === 0; i++) await new Promise((r) => setTimeout(r, 20));
  assert.ok(diagnosticSets.length > 0 && diagnosticSets[0][1].length > 0, 'diagnostics shown');
  handlers.change({ document: doc('// The answer.\ni32 Answer() => 42;\ni32 v = Answer();\n', 2) });
  const h = await handlers.hover.provideHover(doc('', 2), new Position(2, 9));
  assert.match(h.contents.value, /The answer\./);
  await ext.deactivate();
});
