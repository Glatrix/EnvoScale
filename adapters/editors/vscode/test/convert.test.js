// What the server answers, as VS Code's types (a stand-in vscode module).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const convert = require('../convert');

class Position { constructor(line, character) { Object.assign(this, { line, character }); } }
class Range {
  constructor(start, end) {
    if (end.line < start.line || (end.line === start.line && end.character < start.character)) throw new Error('backwards range');
    Object.assign(this, { start, end });
  }
  contains(r) {
    const le = (a, b) => a.line < b.line || (a.line === b.line && a.character <= b.character);
    return le(this.start, r.start) && le(r.end, this.end);
  }
}
const vs = {
  Position,
  Range,
  Uri: { parse: (s) => ({ s }) },
  Location: class { constructor(uri, range) { Object.assign(this, { uri, range }); } },
  Diagnostic: class { constructor(range, message, severity) { Object.assign(this, { range, message, severity }); } },
  DiagnosticSeverity: { Error: 0, Warning: 1, Information: 2, Hint: 3 },
  MarkdownString: class { constructor(value) { this.value = value; } },
  Hover: class { constructor(contents, range) { Object.assign(this, { contents, range }); } },
  CompletionItem: class { constructor(label, kind) { Object.assign(this, { label, kind }); } },
  CompletionItemKind: { Text: 0, Method: 1, Function: 2, Constructor: 3, Field: 4, Variable: 5, Class: 6, Interface: 7, Module: 8, Property: 9, Enum: 12, Keyword: 13, EnumMember: 19, Constant: 20, Struct: 21, TypeParameter: 24 },
  SymbolKind: { Variable: 12 },
  SymbolInformation: class { constructor(name, kind, container, location) { Object.assign(this, { name, kind, container, location }); } },
  DocumentSymbol: class {
    constructor(name, detail, kind, range, selectionRange) {
      // as VS Code checks
      if (!range.contains(selectionRange)) throw new Error('selectionRange must be contained in fullRange');
      Object.assign(this, { name, detail, kind, range, selectionRange, children: [] });
    }
  },
  TextEdit: class { constructor(range, newText) { Object.assign(this, { range, newText }); } },
};
const r = (l0, c0, l1, c1) => ({ start: { line: l0, character: c0 }, end: { line: l1, character: c1 } });

test('diagnostics keep their range, severity and code', () => {
  const ds = convert.diagnostics(vs, { uri: 'file:///a.envo', diagnostics: [{ range: r(0, 8, 0, 9), message: 'expected an expression', severity: 1, code: 'E0101' }] });
  assert.strictEqual(ds.length, 1);
  assert.strictEqual(ds[0].severity, vs.DiagnosticSeverity.Error);
  assert.strictEqual(ds[0].code, 'E0101');
  assert.strictEqual(ds[0].range.start.character, 8);
});

test('a symbol whose range does not hold its name is widened', () => {
  // as envo lsp answers for a one-line function today
  const s = convert.symbols(vs, [{ name: 'Answer', detail: 'i32 Answer()', kind: 12, range: r(1, 0, 1, 0), selectionRange: r(1, 4, 1, 10) }], 'file:///a.envo');
  assert.strictEqual(s[0].kind, 11);
  assert.deepStrictEqual([s[0].range.start.character, s[0].range.end.character], [0, 10]);
});

test('completion kinds map from the protocol', () => {
  const items = convert.completions(vs, { isIncomplete: false, items: [{ label: 'X', kind: 5, detail: 'i32 X' }, { label: 'Point', kind: 22 }] });
  assert.deepStrictEqual(items.map((i) => [i.label, i.kind]), [['X', vs.CompletionItemKind.Field], ['Point', vs.CompletionItemKind.Struct]]);
  assert.strictEqual(items[0].detail, 'i32 X');
});

test('hover markdown and locations', () => {
  const h = convert.hover(vs, { contents: { kind: 'markdown', value: '```envo\ni32 Answer()\n```' } });
  assert.match(h.contents.value, /Answer/);
  assert.strictEqual(convert.hover(vs, null), null);
  const ls = convert.locations(vs, { uri: 'file:///a.envo', range: r(1, 4, 1, 10) });
  assert.strictEqual(ls.length, 1);
  assert.strictEqual(ls[0].range.end.character, 10);
});
