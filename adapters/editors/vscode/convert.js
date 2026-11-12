// convert.js: what envo lsp answers, as VS Code's types. Each function takes the vscode
// module, so tests pass a stand-in (test/convert.test.js).
'use strict';

const position = (vs, p) => new vs.Position(p.line, p.character);
const range = (vs, r) => new vs.Range(position(vs, r.start), position(vs, r.end));
const toPosition = (p) => ({ line: p.line, character: p.character });

function diagnostics(vs, params) {
  return (params.diagnostics || []).map((d) => {
    const severity = [null, vs.DiagnosticSeverity.Error, vs.DiagnosticSeverity.Warning,
      vs.DiagnosticSeverity.Information, vs.DiagnosticSeverity.Hint][d.severity || 1];
    const out = new vs.Diagnostic(range(vs, d.range), d.message, severity);
    if (d.code !== undefined) out.code = d.code;
    out.source = d.source || 'envo';
    return out;
  });
}

function hover(vs, h) {
  if (!h || !h.contents) return null;
  const c = h.contents;
  const text = typeof c === 'string' ? c : c.value !== undefined ? c.value : Array.isArray(c) ? c.map((x) => x.value || x).join('\n\n') : '';
  const md = new vs.MarkdownString(text);
  return h.range ? new vs.Hover(md, range(vs, h.range)) : new vs.Hover(md);
}

// LSP CompletionItemKind (1-25) as VS Code's (which counts from 0).
function completionKind(vs, k) {
  const K = vs.CompletionItemKind;
  const map = {
    2: K.Method, 3: K.Function, 4: K.Constructor, 5: K.Field, 6: K.Variable, 7: K.Class, 8: K.Interface,
    9: K.Module, 10: K.Property, 13: K.Enum, 14: K.Keyword, 20: K.EnumMember, 21: K.Constant, 22: K.Struct,
    25: K.TypeParameter,
  };
  return map[k] !== undefined ? map[k] : K.Text;
}

function completions(vs, result) {
  const items = Array.isArray(result) ? result : (result && result.items) || [];
  return items.map((i) => {
    const out = new vs.CompletionItem(i.label, completionKind(vs, i.kind));
    if (i.detail) out.detail = i.detail;
    if (i.documentation) out.documentation = new vs.MarkdownString(typeof i.documentation === 'string' ? i.documentation : i.documentation.value);
    if (i.insertText) out.insertText = i.insertText;
    if (i.sortText) out.sortText = i.sortText;
    return out;
  });
}

function locations(vs, result) {
  if (!result) return [];
  const all = Array.isArray(result) ? result : [result];
  return all.map((l) => new vs.Location(vs.Uri.parse(l.uri), range(vs, l.range)));
}

// LSP SymbolKind (1-26) as VS Code's (from 0).
const symbolKind = (vs, k) => (Number.isInteger(k) && k >= 1 ? k - 1 : vs.SymbolKind.Variable);

function symbols(vs, result, uri) {
  if (!result) return [];
  return result.map((s) => {
    if (s.location) {
      return new vs.SymbolInformation(s.name, symbolKind(vs, s.kind), s.containerName || '', new vs.Location(vs.Uri.parse(s.location.uri || uri), range(vs, s.location.range)));
    }
    // VS Code requires the full range to hold the name's: widen it where it does not
    const sel = s.selectionRange || s.range;
    const before = (a, b) => a.line < b.line || (a.line === b.line && a.character < b.character);
    const full = {
      start: before(sel.start, s.range.start) ? sel.start : s.range.start,
      end: before(s.range.end, sel.end) ? sel.end : s.range.end,
    };
    const out = new vs.DocumentSymbol(s.name, s.detail || '', symbolKind(vs, s.kind), range(vs, full), range(vs, sel));
    out.children = symbols(vs, s.children || [], uri);
    return out;
  });
}

function edits(vs, result) {
  return (result || []).map((e) => new vs.TextEdit(range(vs, e.range), e.newText));
}

module.exports = { diagnostics, hover, completions, locations, symbols, edits, toPosition, completionKind };
