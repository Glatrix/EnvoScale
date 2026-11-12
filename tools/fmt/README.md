# `tools/fmt`

> **Status:** Experimental (M5): `envo fmt`, implemented in
> [`tools/envo/fmt.envo`](../envo/fmt.envo). Tests: `tests/golden/fmt/`.

The one canonical formatter. No configuration. It works on the compiler's tokens and the
text between them (comments and line breaks), keeps the author's line breaks, and sets
indentation, blank lines and spacing; it lexes its own output again and refuses to write
a file whose tokens would change. Rules: the comment at the top of `fmt.envo`.

`envo fmt --check` over `lib`, `adapters`, `tools`, `tests/conformance`, `compiler`,
`bootstrap/stage1` and `examples` is part of `bootstrap.* test`: the repository's own
code stays in the canonical layout. Files that start with `// Generated` are left to
their generator.

Later: a lossless concrete syntax tree from the query-based compiler (brief §8), so the
formatter can also break long lines and join short ones.
