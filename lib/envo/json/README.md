# `envo.json`

> **Status:** Experimental (M5): reader and compact writer, in Envo-S1. Tests:
> `lib/envo/json/tests/`. `[Derive(Json)]` and a streaming tokenizer come later.

JSON (RFC 8259) reader and writer. The language server (`envo lsp`) speaks it.

## Simple door

```envo
use envo.json;
var msg = json.Parse(text).Unwrap();
str? method = msg.GetStr("method");
print(json.Write(msg).AsStr());
```

## Full-control door

- `json.Parse(text)` gives a `Value`, or a `JsonError` with the byte offset and what was
  wrong. It checks escapes, surrogate pairs, number syntax and duplicate keys, and
  limits nesting to 512 levels.
- A `Value` is `Null`, `Bool`, `Number` (its text kept; `HasInt`/`AsInt` for integers
  that fit in `i64`, `AsFloat` for any number), `Str`, `Array` or `Object` (members in
  order). Read it with
  `Type`, `AsBool`, `AsStr`, `Elements`, `Len`, `KeyAt`, `Field`, `Has`, `GetStr`,
  `GetInt`; build it with `Value.Null`, `OfBool`, `OfInt`, `OfFloat`, `OfStr`, `NewArray` (`Push`)
  and `NewObject` (`Set`); `Clone` copies one.
- `json.Write(v)` gives compact text; `json.Quote` appends one string literal.

## Ports used

none
