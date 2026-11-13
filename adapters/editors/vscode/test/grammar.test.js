// The manifest, editor settings and grammar: every file package.json names exists and
// parses, every pattern compiles, and the grammar scopes a line of Envol as expected.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..');
const json = (p) => JSON.parse(fs.readFileSync(path.join(dir, p), 'utf8'));
const pkg = json('package.json');
const grammar = json('syntaxes/envol.tmLanguage.json');

test('package.json names files that exist', () => {
  assert.ok(fs.existsSync(path.join(dir, pkg.main)));
  for (const l of pkg.contributes.languages) json(l.configuration);
  for (const g of pkg.contributes.grammars) {
    assert.strictEqual(json(g.path).scopeName, g.scopeName);
  }
  assert.deepStrictEqual(Object.keys(pkg.dependencies || {}), [], 'no npm dependencies');
});

// Every regular expression in a grammar node and below it.
function* patterns(node) {
  if (!node || typeof node !== 'object') return;
  for (const key of ['match', 'begin', 'end']) if (typeof node[key] === 'string') yield node[key];
  for (const v of Object.values(node)) {
    if (Array.isArray(v)) for (const x of v) yield* patterns(x);
    else if (typeof v === 'object') yield* patterns(v);
  }
}

test('every pattern compiles', () => {
  let n = 0;
  for (const p of patterns(grammar)) {
    assert.doesNotThrow(() => new RegExp(p), p);
    n++;
  }
  assert.ok(n > 20);
});

test('includes name rules that exist', () => {
  const names = new Set(Object.keys(grammar.repository));
  for (const node of [grammar, ...Object.values(grammar.repository)]) {
    const text = JSON.stringify(node);
    for (const m of text.matchAll(/"include":"#([^"]+)"/g)) assert.ok(names.has(m[1]), m[1]);
  }
});

// The scope a rule gives the first match of re in line.
const scopeOf = (rule, line) => {
  const r = grammar.repository[rule];
  const all = r.patterns || [r];
  for (const p of all) {
    if (p.match && new RegExp(p.match).test(line)) return p.name || Object.values(p.captures || {}).map((c) => c.name).join(' ');
  }
  return null;
};

test('a line of Envol gets its scopes', () => {
  assert.strictEqual(scopeOf('keywords', 'return x;'), 'keyword.control.envol');
  assert.strictEqual(scopeOf('keywords', 'public static'), 'storage.modifier.envol');
  assert.strictEqual(scopeOf('types', 'usize n'), 'support.type.primitive.envol');
  assert.strictEqual(scopeOf('numbers', 'x = 0xFF_u8;'), 'constant.numeric.hex.envol');
  assert.strictEqual(scopeOf('comments', '/// The answer.'), 'comment.line.documentation.envol');
  assert.strictEqual(scopeOf('declarations', 'struct Point {'), 'keyword.declaration.envol entity.name.type.envol');
  assert.ok(!new RegExp(grammar.repository.types.match).test('i32x'));
});
