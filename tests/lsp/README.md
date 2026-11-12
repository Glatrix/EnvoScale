# `tests/lsp` — the language server

> **Status:** M5. Run by `bootstrap.ps1 test` / `bootstrap.sh test` ("envo lsp").

`session.jsonl` is what an editor sends, one JSON message per line; `${URI}` stands for
the document's `file:` URI (`build/run-lsp/doc.envo` under the repository). The scripts
frame each line with its `Content-Length` header, pipe the session into `envo lsp`, and
compare the bodies it writes back, one per line, with `expected.jsonl`. The session
opens a document with an error, fixes it, introduces another after an emoji (checking
UTF-16 columns), asks for an unsupported method, closes the document and shuts down.
