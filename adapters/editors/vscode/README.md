# `adapters/editors/vscode`

> **Status:** Experimental (M14.9). Tests: `test/` (`node --test`), in CI against the
> `envo` the build makes. Not on the Marketplace yet.

The Envol extension for Visual Studio Code, in plain JavaScript with **no npm
dependencies**: nothing to install, nothing to audit but these files.

| File | What it does |
|---|---|
| `package.json` | The manifest: the `envo` language for `.envol` files, the grammar, settings (`envo.path`, `envo.trace`) and the restart command |
| `syntaxes/envo.tmLanguage.json` | Highlighting: comments (nested block comments, `///` doc comments), strings (escapes, raw `"""` strings, `$"…{x}…"` interpolation), numbers with suffixes, keywords and modifiers from the lexical spec, primitive types, declarations, calls |
| `language-configuration.json` | Comment toggling, brackets, auto-closing pairs, indentation, `///` continuing on Enter |
| `lsp.js` | A Language Server Protocol client over a child process (framing, requests, notifications); knows nothing of VS Code |
| `convert.js` | The server's answers as VS Code's types |
| `extension.js` | Starts `envo lsp`, keeps it told of open documents (whole text on each change), and wires diagnostics, completion, hover, go to definition, document symbols and formatting to it |

## Install from this folder

1. Build EnvoScale (`./build.sh build`, or `.\build.ps1 build`) and put
   `build/envo` on `PATH`, or set **Envol: Path** (`envo.path`) to the program.
2. Copy this folder to your VS Code extensions folder as `envoscale.envol-0.1.0`:
   `%USERPROFILE%\.vscode\extensions\` on Windows, `~/.vscode/extensions/` elsewhere.
3. Restart VS Code and open a `.envol` file.

"Envol: Restart the Language Server" restarts `envo lsp` after rebuilding it; the **Envol**
output channel shows what the server says (and every message with `envo.trace` on).

## Tests

```bash
ENVO=build/envo/envo node --test adapters/editors/vscode/test/*.test.js
```

`lsp.test.js` checks the framing, `grammar.test.js` the manifest and every pattern,
`convert.test.js` the conversions (with a stand-in `vscode` module), `session.test.js` a
whole session with the real server, and `extension.test.js` the extension's wiring
against a stand-in `vscode`. The last two need `ENVO`; without it they check less.

## Not yet

Packaging as a `.vsix` and publishing to the Marketplace (the owner's call), semantic
highlighting, rename, find references, signature help, and a debugger (M15.5).
