# Diagnostic Codes

> **Status:** Live registry. Every code a compiler stage can emit is listed here.
> `envo explain EXXXX` (M5) prints these entries.

Codes are stable: once assigned, a code keeps its meaning forever. A retired code is
marked retired, never reused.

## Ranges

| Range | Phase |
|---|---|
| E0001–E0099 | Lexical |
| E0100–E0199 | Syntax |
| E0200–E0299 | Names and modules |
| E0300–E0499 | Types and interfaces |
| E0500–E0599 | Ownership and borrowing |
| E0600–E0899 | Reserved |
| E0900–E0999 | "Not part of Envo-Core" (Stage 0 only) |

## Format

```text
<file>:<line>:<col>: error[E0004]: unterminated string literal
```

Lines and columns are 1-based; columns count Unicode scalar values (§1.1). Stage 2 adds
labelled source snippets and `help:` lines (see chapter 5, §5.5).

## Lexical (E0001–E0099)

| Code | Message | Reported at | Rule |
|---|---|---|---|
| E0001 | source file is not valid UTF-8 | first invalid byte | [lex.src.1] |
| E0002 | unexpected character | the character | [lex.ws.1], [lex.ident.3], [lex.punct.4] |
| E0003 | unterminated block comment | the opening `/*` | [lex.comment.2] |
| E0004 | unterminated string literal | the opening `"` | [lex.str.1] |
| E0005 | unterminated character literal | the opening `'` | [lex.char.1] |
| E0006 | unknown or malformed escape sequence | the `\` | [lex.esc.1] |
| E0007 | malformed numeric literal | the literal, or the offending digit | [lex.int.2], [lex.float.3] |
| E0008 | invalid suffix on numeric literal | the suffix | [lex.int.3], [lex.float.3] |
| E0009 | character literal must contain exactly one character | the opening `'` | [lex.char.1] |
| E0010 | invalid Unicode escape | the `\` | [lex.esc.2] |
| E0011 | control character in literal; use an escape sequence | the character | [lex.esc.3] |

## Ownership (E0500–E0599) — reserved by the chapter 5 draft

| Code | Message |
|---|---|
| E0501 | value used after move |
| E0502 | cannot move out of a borrow |
| E0503 | conflicting borrows |
| E0504 | value moved or dropped while borrowed |
| E0505 | `out` parameter not assigned on every path |
| E0506 | cannot infer the lifetime of a returned borrow |
| E0510 | allocation in a `[NoAlloc]` function |

## Not part of Envo-Core (E0900–E0999)

| Code | Message |
|---|---|
| E0901 | interpolated strings are not part of Envo-Core |
| E0902 | raw string literals are not part of Envo-Core |
| E0903 | directives are not part of Envo-Core |
| E0904 | non-ASCII characters outside literals and comments are not supported in Envo-Core |
| E0905 | this construct is not part of Envo-Core (parser; message names the construct) |
