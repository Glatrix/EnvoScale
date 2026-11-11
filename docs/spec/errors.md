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
| E0600–E0699 | EIR text and verifier ([`eir.md`](eir.md) §3, §6) |
| E0700–E0899 | Reserved |
| E0900–E0949 | "Not part of Envo-Core" (Stage 0, and `envoc1 --core`) |
| E0950–E0999 | "Not part of Envo-S1" (Stage 1) |

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

## Syntax (E0100–E0199)

| Code | Message | Reported at | Rule |
|---|---|---|---|
| E0101 | expected X, found Y | the unexpected token | [core.syntax.1] |
| E0102 | comparison operators cannot be chained; use `&&` or parentheses | the second operator | [core.syntax.2] |
| E0103 | invalid target for assignment | the assignment operator | [core.syntax.3] |
| E0104 | nested too deeply (Stage 0 limit: 256 levels) | the token where the limit is exceeded | [core.syntax.4] |

## Names (E0200–E0299)

| Code | Message | Rule |
|---|---|---|
| E0201 | `x` is already defined | [core.name.1], [core.name.4] |
| E0202 | unknown type `x` | [core.name.3] |
| E0203 | unknown name `x` | [core.name.3] |
| E0204 | `x` is already declared in this function | [core.name.2] |
| E0205 | `break`/`continue` outside a loop | [core.stmt.5] |
| E0206 | `T` has no member `x` | [core.expr.7] |
| E0207 | field `x` is set twice | [core.expr.10] |
| E0208 | `x` is not a type | [core.name.3] |
| E0209 | `x` is a type, not a value | [core.name.3] |
| E0210 | top-level statements are only allowed in the entry file (the first file given) | [item.mod.3] |

## Types (E0300–E0399)

| Code | Message | Rule |
|---|---|---|
| E0301 | mismatched types: expected `T`, found `U` | [core.expr.2] |
| E0302 | operator cannot be applied to `T` | [core.expr.3], [core.expr.4] |
| E0303 | struct `S` contains itself | [core.type.2] |
| E0304 | value does not fit in `T` | [core.expr.1], [core.type.4] |
| E0305 | cannot convert `T` to `U` | [core.expr.9] |
| E0306 | this needs an `unsafe` block | [core.expr.5]–[core.expr.9] |
| E0307 | wrong number of arguments: expected N, found M | [core.expr.8] |
| E0308 | `match` is not exhaustive | [core.stmt.7] |
| E0309 | constant `x` depends on itself | [core.const.2] |
| E0310 | constant evaluation failed (overflow, division by zero, or shift too large) | [core.const.2] |
| E0311 | expected a constant expression | [core.const.1], [core.type.1] |
| E0312 | type is too large | [core.type.2] |
| E0314 | this cannot be called | [core.expr.8] |
| E0315 | cannot assign to this | [core.stmt.3] |
| E0316 | cannot take the address of this | [core.expr.5] |
| E0317 | `return` does not match the function's return type | [core.stmt.6] |
| E0319 | this value is already matched | [core.stmt.7] |
| E0320 | not all code paths return a value | [core.stmt.6] |
| E0321 | only calls can be used as statements | [core.stmt.2] |
| E0322 | a `void` value cannot be used here | [core.expr.11] |
| E0323 | duplicate enum value | [core.type.4] |
| E0324 | enum representation must be an integer type | [core.type.4] |
| E0327 | `void` is only allowed as a return type | [core.type.1] |
| E0328 | cannot slice `T` | [expr.slice.1] (Envo-S1, RFC 0002) |
| E0329 | cannot slice a temporary array; store it in a variable first | [expr.slice.4] (Envo-S1, RFC 0002) |
| E0330 | cannot infer the type of lambda parameter `x`; write its type | [fn.lam.1] (Envo-S1, RFC 0003) |
| E0331 | this lambda changes (or moves) `x`, but the target is a `fn` (or `mut fn`) | [fn.type.4] (Envo-S1, RFC 0003) |
| E0332 | calling a `mut fn` needs `ref` or owned access, not a shared borrow | [fn.type.3] (Envo-S1, RFC 0003) |
| E0333 | `mut` only applies to `fn` types and slices | [view.2] (Envo-S1, RFC 0004) |
| E0350 | generic instantiation too deep | [s1.type.2] (Envo-S1) |

## Ownership (E0500–E0599) — reserved by the chapter 5 draft

| Code | Message |
|---|---|
| E0501 | value used after move |
| E0502 | cannot move out of a borrow |
| E0503 | conflicting borrows |
| E0504 | value moved or dropped while borrowed |
| E0505 | `out` parameter not assigned on every path |
| E0506 | cannot infer the lifetime of a returned borrow |
| E0507 | this returns (or stores) a borrow of `x`, but the signature does not say `from x` ([life.from.3], RFC 0004) |
| E0508 | `from` can only name a borrowed parameter or `this` ([life.from.2], RFC 0004) |
| E0510 | allocation in a `[NoAlloc]` function |

## Not part of Envo-Core (E0900–E0949)

| Code | Message |
|---|---|
| E0901 | interpolated strings are not part of Envo-Core |
| E0902 | raw string literals are not part of Envo-Core |
| E0903 | directives are not part of Envo-Core |
| E0904 | non-ASCII characters outside literals and comments are not supported in Envo-Core |
| E0905 | not part of Envo-Core: X (the message names the construct; [core.syntax.5]) |

## Not part of Envo-S1 (E0950–E0999)

| Code | Message |
|---|---|
| E0950 | not part of Envo-S1: X (the message names the construct; [s1.subset.4]) |

## EIR (E0600–E0699)

Reported by `envoc1 eir-check` for EIR text, at the token or instruction concerned. EIR
that the compiler builds itself is verified the same way, and a failure there is an
internal error.

| Code | Message | Rule |
|---|---|---|
| E0601 | EIR syntax: expected X, found Y | [eir.text.1]–[eir.text.3] |
| E0602 | unsupported EIR version N (this reader knows version 1) | [eir.ver.1] |
| E0603 | unknown name | [eir.verify.1] |
| E0604 | name defined twice | [eir.verify.1] |
| E0605 | mismatched types in an instruction | [eir.verify.3] |
| E0606 | a block must end with exactly one terminator | [eir.verify.2] |
| E0607 | branch arguments do not match the target block's parameters | [eir.verify.2] |
| E0608 | a value is used where its definition does not dominate | [eir.verify.4] |
| E0609 | `slot` only at the start of the entry block | [eir.verify.5] |
| E0610 | call or `ret` does not match the function's signature | [eir.verify.6] |
| E0611 | invalid field index, duplicate `switch` key or unknown panic reason | [eir.verify.7] |
| E0612 | struct type contains itself | [eir.verify.1] |
| E0613 | constant does not fit its type | [eir.verify.3] |
| E0614 | unknown instruction or intrinsic | [eir.text.1] |
