# `envo.eon`

> **Status:** Experimental (M5): reader and canonical writer, in Envo-S1. Tests:
> `lib/envo/eon/tests/`. `[Derive(Eon)]` and binary EON come later (they need
> derives, M6+).

EON (Envo Object Notation) reader and writer. Spec: [`docs/spec/eon.md`](../../../docs/spec/eon.md).

## Simple door

```envo
use envo.eon;
var doc = eon.Load("envo.envon").Unwrap();
str name = doc.Field("package")[0].GetStr("name").Unwrap();
```

## Full-control door

- `eon.Parse(text)` reads a document from text: a `Value` (a block of entries in the
  order written), or a `ParseError` with its line, column and message
  (`e.Describe()` gives `line:col: message`).
- A `Value` is one of `Null`, `Bool`, `Int` (with its type suffix), `Float` (kept as
  written), `Str`, `Array`, `Block`. Read it with `Type`, `AsBool`, `AsInt`, `AsStr`,
  `Elements`, `Len`, `KeyAt`, `Field`, `Has`, `GetStr`, `GetInt`, `GetBool`.
- Build one with `Value.OfNull`, `OfBool`, `OfInt`, `OfStr`, `NewArray` (`Push`) and
  `NewBlock` (`Set`, which replaces an entry in its place).
- `eon.Write(doc)` gives the canonical text (spec section 5): the version line, 4-space
  indentation, one entry per line, `=` aligned within a block, arrays of scalars on one
  line when they fit in 80 columns.

The reader checks what the spec asks: valid UTF-8, the version line, duplicate keys,
escapes, number suffixes and ranges. It rejects raw and interpolated strings. Comments
are skipped, so `Write` does not keep them.

## Ports used

FileSystem, through `std.fs`, only in `Load`.
