// The Envo extension for VS Code (M14.9): the grammar and editor settings come from
// package.json; this file runs `envo lsp` and connects it to the editor: documents are sent
// whole as they change, diagnostics shown as they come, and completion, hover, go to
// definition, document symbols and formatting asked of the server.
'use strict';
const vscode = require('vscode');
const { Client } = require('./lsp');
const convert = require('./convert');

let client = null;
let output = null;
let diagnostics = null;
let warned = false;

const isEnvo = (doc) => doc.languageId === 'envo';
const docParams = (doc) => ({ textDocument: { uri: doc.uri.toString() } });

async function start(context) {
  const config = vscode.workspace.getConfiguration('envo');
  const program = config.get('path') || 'envo';
  const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
  const c = new Client(program, ['lsp'], {
    cwd: folder ? folder.uri.fsPath : undefined,
    trace: config.get('trace'),
    onLog: (t) => output.appendLine(t.replace(/\s+$/, '')),
    onNotification: (method, params) => {
      if (method === 'textDocument/publishDiagnostics') {
        diagnostics.set(vscode.Uri.parse(params.uri), convert.diagnostics(vscode, params));
      }
    },
    onExit: (code) => {
      if (client === c) output.appendLine(`envo lsp exited (${code}); "Envo: Restart the Language Server" starts it again`);
    },
  });
  try {
    await c.start(folder ? folder.uri.toString() : null);
  } catch (e) {
    output.appendLine(`could not start ${program} lsp: ${e.message}`);
    if (!warned) {
      warned = true;
      vscode.window.showWarningMessage(`Envo: could not start "${program} lsp". Set envo.path to the envo program.`);
    }
    return;
  }
  client = c;
  for (const doc of vscode.workspace.textDocuments) opened(doc);
}

async function stop() {
  const c = client;
  client = null;
  if (c) await c.stop();
  if (diagnostics) diagnostics.clear();
}

function opened(doc) {
  if (!client || !isEnvo(doc)) return;
  client.notify('textDocument/didOpen', {
    textDocument: { uri: doc.uri.toString(), languageId: 'envo', version: doc.version, text: doc.getText() },
  });
}

// A request for the document at doc, or null when the server is not running.
async function ask(method, params) {
  if (!client) return null;
  try {
    return await client.request(method, params);
  } catch (e) {
    output.appendLine(`${method}: ${e.message}`);
    return null;
  }
}

function activate(context) {
  output = vscode.window.createOutputChannel('Envo');
  diagnostics = vscode.languages.createDiagnosticCollection('envo');
  const selector = { language: 'envo' };
  context.subscriptions.push(
    output,
    diagnostics,
    vscode.workspace.onDidOpenTextDocument(opened),
    vscode.workspace.onDidChangeTextDocument((e) => {
      if (!client || !isEnvo(e.document)) return;
      client.notify('textDocument/didChange', {
        textDocument: { uri: e.document.uri.toString(), version: e.document.version },
        contentChanges: [{ text: e.document.getText() }],
      });
    }),
    vscode.workspace.onDidSaveTextDocument((doc) => {
      if (client && isEnvo(doc)) client.notify('textDocument/didSave', docParams(doc));
    }),
    vscode.workspace.onDidCloseTextDocument((doc) => {
      if (!client || !isEnvo(doc)) return;
      client.notify('textDocument/didClose', docParams(doc));
      diagnostics.delete(doc.uri);
    }),
    vscode.languages.registerCompletionItemProvider(selector, {
      async provideCompletionItems(doc, pos) {
        return convert.completions(vscode, await ask('textDocument/completion', { ...docParams(doc), position: convert.toPosition(pos) }));
      },
    }, '.'),
    vscode.languages.registerHoverProvider(selector, {
      async provideHover(doc, pos) {
        return convert.hover(vscode, await ask('textDocument/hover', { ...docParams(doc), position: convert.toPosition(pos) }));
      },
    }),
    vscode.languages.registerDefinitionProvider(selector, {
      async provideDefinition(doc, pos) {
        return convert.locations(vscode, await ask('textDocument/definition', { ...docParams(doc), position: convert.toPosition(pos) }));
      },
    }),
    vscode.languages.registerDocumentSymbolProvider(selector, {
      async provideDocumentSymbols(doc) {
        return convert.symbols(vscode, await ask('textDocument/documentSymbol', docParams(doc)), doc.uri.toString());
      },
    }),
    vscode.languages.registerDocumentFormattingEditProvider(selector, {
      async provideDocumentFormattingEdits(doc, options) {
        return convert.edits(vscode, await ask('textDocument/formatting', { ...docParams(doc), options: { tabSize: options.tabSize, insertSpaces: options.insertSpaces } }));
      },
    }),
    vscode.commands.registerCommand('envo.restart', async () => {
      await stop();
      await start(context);
    }),
    vscode.workspace.onDidChangeConfiguration(async (e) => {
      if (e.affectsConfiguration('envo.path') || e.affectsConfiguration('envo.trace')) {
        await stop();
        await start(context);
      }
    }),
  );
  return start(context);
}

function deactivate() {
  return stop();
}

module.exports = { activate, deactivate };
