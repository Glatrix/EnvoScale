# `tests/lsp`: the language server

> **Status:** M5. Run by `build.ps1 test` / `build.sh test` ("envo lsp").

`session.jsonl` is what an editor sends, one JSON message per line; `${URI}` stands for
the document's `file:` URI (`build/run-lsp/doc.envol` under the repository). The scripts
frame each line with its `Content-Length` header, pipe the session into `envo lsp`, and
compare the bodies it writes back, one per line, with `expected.jsonl`. The session
opens a document with an error, fixes it, and asks about the fixed program (M14.4, PLAN
D75): hover over a function (its signature and doc comment), go to its definition and to
a field's, completion after `p.` (the struct's fields) and the document's symbols. Then it
introduces another error after an emoji (checking UTF-16 columns), asks for hover without
a position, closes the document and shuts down.
