# `tools/lsp`

> **Status:** Experimental (M5): `envo lsp`, in [`tools/envo/lsp.envo`](../envo/lsp.envo).
> Diagnostics only (PLAN D30). Tests: `tests/lsp/`.

A language server over the Language Server Protocol's base protocol (JSON-RPC with
`Content-Length` framing, on standard input and output), using `envo.json`.

| Message | What `envo lsp` does |
|---|---|
| `initialize` | Answers with full-text document sync (`openClose`, `change: 1`, `save`) |
| `textDocument/didOpen`, `didChange`, `didSave` | Writes the text to `build/envo-lsp/<server>/` beside the file (a folder of this server's own, removed when it exits), runs `envo check` on it (with the rest of its package) as a child process, and publishes the first error, with its code and `help:` line |
| `textDocument/didClose` | Clears the document's diagnostics |
| `shutdown`, `exit` | Ends; the exit code is 0 if `shutdown` came first |
| any other request | Answers with error -32601 (method not found) |

Positions are converted to UTF-16 code units, as the protocol counts them.

Editors start it as `envo lsp`. Hover, completion and go-to-definition need the
query-based compiler (brief §8) and come later.
