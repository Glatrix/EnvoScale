# 1. Lexical Structure

> **Status:** Normative. Implemented by Stage 0 (`bootstrap/stage0/src/lexer.eas`).
> Constructs outside Envo-Core are specified here in full; Stage 0 rejects them with
> `E09xx` diagnostics (see §1.11).

The lexer turns a source file into a sequence of **tokens**. Whitespace and comments
(**trivia**) separate tokens but are not tokens themselves; a lossless lexer (used by
the formatter and LSP) keeps them attached to the following token.

## 1.1 Source text

**[lex.src.1]** A source file is a sequence of bytes that must be valid UTF-8 (RFC 3629):
no overlong encodings, no encoded surrogates (U+D800–U+DFFF), nothing above U+10FFFF.
Otherwise the file is rejected with **E0001** at the first invalid byte.
Tests: `tests/spec/01-lexical/e0001_invalid_utf8.bin.envo`, `e0001_surrogate.bin.envo`.

**[lex.src.2]** A UTF-8 byte order mark (EF BB BF) at the very start of the file is
ignored. It is not part of the first line for column counting.
Tests: `tests/golden/lexer/bom.envo`.

**[lex.src.3]** Source files use the extension `.envo`. EON files (`.eon`) use the same
lexical rules (see `eon.md`).

**[lex.src.4] Positions.** Lines are numbered from 1 and end at LF (U+000A). A CR
(U+000D) is whitespace and never ends a line by itself, so CRLF files have the same line
numbers as LF files. Columns are numbered from 1 and count Unicode scalar values from
the start of the line. Every diagnostic and tool reports positions this way.
Tests: `tests/golden/lexer/strings.envo` (columns after multi-byte characters).

## 1.2 Shebang

**[lex.shebang.1]** If the file (after any BOM) begins with `#!`, everything up to but
not including the first LF is ignored. This lets a script start with
`#!/usr/bin/env envo`. `#!` anywhere else is not special.
Tests: `tests/golden/lexer/shebang.envo`.

## 1.3 Whitespace

**[lex.ws.1]** Whitespace is exactly: space (U+0020), horizontal tab (U+0009), line
feed (U+000A) and carriage return (U+000D). Any other control character outside a
comment or literal is an **unexpected character (E0002)**.
Tests: `tests/spec/01-lexical/e0002_form_feed.bin.envo`.

*Rationale:* a closed set keeps files unambiguous across editors; invisible Unicode
spaces cannot change how code tokenizes.

## 1.4 Comments

```
LineComment  = '//' ~LF*
BlockComment = '/*' ( BlockComment | ~'*/' )* '*/'
```

**[lex.comment.1]** `//` starts a comment that runs to the end of the line. `///` is a
**doc comment**: lexically identical, but attached to the following item by the
documentation tools.

**[lex.comment.2]** `/*` starts a block comment that ends at the matching `*/`. Block
comments **nest**: `/* a /* b */ c */` is one comment. An unclosed block comment is
**E0003**, reported at its opening `/*`.
Tests: `tests/golden/lexer/comments.envo`, `tests/spec/01-lexical/e0003_unterminated_block_comment.envo`.

*Rationale:* nesting makes "comment out this region" always work, even when the region
already contains block comments.

## 1.5 Token spacing flags

Envo uses whitespace in two places in its grammar (`?` and line breaks; see chapter 3),
so each token records how it was separated from the previous one.

**[lex.flags.1]** A token has the **space-before** flag if it is the first token in the
file, or if any whitespace or comment appears between it and the previous token.

**[lex.flags.2]** A token has the **newline-before** flag if it is the first token in the
file, or if at least one LF appears between it and the previous token (including an LF
inside a block comment). newline-before implies space-before.

**[lex.flags.3]** A token with neither flag is **joint** with the previous token.

Tests: `tests/golden/lexer/flags.envo`. The token dump prints `n` (newline-before),
`s` (space-before only) or `j` (joint).

## 1.6 Identifiers and keywords

```
Identifier    = IdentStart IdentContinue* | '@' IdentStart IdentContinue*
IdentStart    = XID_Start | '_'
IdentContinue = XID_Continue
```

**[lex.ident.1]** Identifiers follow Unicode UAX #31 (XID_Start / XID_Continue) plus
`_`. Identifiers are compared after NFC normalization.

**[lex.ident.2]** A word that spells a reserved keyword (§1.6.1) is a keyword token,
not an identifier.

**[lex.ident.3] Raw identifiers.** `@` immediately followed by an identifier or keyword
spelling forms an identifier with the `@` removed: `@class` is the identifier `class`.
This lets code use names that later editions reserve. `@_` is not valid (E0002), and
`@` on its own is not a token (E0002).

**[lex.ident.4]** A lone `_` is the **discard** token (used in patterns and to ignore
values). Identifiers may start with `_` (`_unused`).

Tests: `tests/golden/lexer/idents.envo`, `tests/golden/lexer/keywords.envo`.

**Core:** identifiers are ASCII only: `[A-Za-z_][A-Za-z0-9_]*`. A non-ASCII character
outside a literal or comment is **E0904**.

### 1.6.1 Reserved keywords

These are reserved in every context:

```
_          abstract   alignof    as         asm        async      await
base       break      catch      class      comptime   const      continue
do         else       enum       extern     false      for        foreach
goto       if         impl       in         interface  internal   macro
match      namespace  new        null       out        override   private
protected  public     ref        return     sealed     sizeof     static
struct     this       throw      true       try        unsafe     use
using      var        virtual    weak       where      while      yield
```

Some (`abstract`, `base`, `catch`, `goto`, `macro`, `override`, `sealed`, `throw`,
`try`, `virtual`, `yield`) have no meaning yet; they are reserved so that future editions
can use them without breaking code.

### 1.6.2 Contextual keywords

These are ordinary identifiers except in the positions chapter 3–4 give them meaning:
`get`, `set`, `init`, `value`, `component`, `unchecked`, and `fn`, `mut`, `once`, `move`
(function types and lambdas, [RFC 0003](../rfcs/0003-function-types.md) [fn.syn.1]).

### 1.6.3 Predeclared names

Primitive type names (`i32`, `u8`, `bool`, `str`, `int`, …; see chapter 2) are **not**
keywords. They are predeclared in the prelude and cannot be redeclared at module scope.

*Rationale:* new primitive types can be added without reserving new words, and the
lexer stays independent of the type system.

## 1.7 Literals

### 1.7.1 Integer literals

```
IntLiteral  = ( DecDigits | '0x' HexDigits | '0o' OctDigits | '0b' BinDigits ) IntSuffix?
DecDigits   = [0-9] [0-9_]*
HexDigits   = [0-9a-fA-F_]* [0-9a-fA-F] [0-9a-fA-F_]*
OctDigits   = [0-7_]* [0-7] [0-7_]*
BinDigits   = [01_]* [01] [01_]*
IntSuffix   = 'i8' | 'i16' | 'i32' | 'i64' | 'i128' | 'isize'
            | 'u8' | 'u16' | 'u32' | 'u64' | 'u128' | 'usize'
```

**[lex.int.1]** `_` may appear anywhere after the first digit (or after the prefix) as a
visual separator and has no meaning. Prefixes are lowercase only.

**[lex.int.2]** A prefix with no digits (`0x`, `0b_`) is **E0007**. A decimal digit that
is not valid for the base (`0b102`, `0o8`) is **E0007**, reported at that digit.

**[lex.int.3]** An optional type suffix may follow directly or after `_` (`255u8`,
`255_u8`). If letters or digits continue the literal and do not form a valid suffix,
the literal has an invalid suffix: **E0008**, reported at the suffix (`10u7`, `0x10g`).

**[lex.int.4]** The lexer does not check range; a literal that does not fit its type is
a type error (chapter 2).

Tests: `tests/golden/lexer/numbers.envo`, `tests/spec/01-lexical/e0007_*.envo`, `e0008_*.envo`.

### 1.7.2 Floating-point literals

```
FloatLiteral = DecDigits ( '.' [0-9] [0-9_]* )? Exponent? FloatSuffix?
Exponent     = ( 'e' | 'E' ) ( '+' | '-' )? [0-9_]* [0-9] [0-9_]*
FloatSuffix  = 'f32' | 'f64'
```

**[lex.float.1]** A decimal literal is a float literal if it has a fraction, an exponent,
or a float suffix (`1.5`, `1e10`, `2f32`). At least one of the three must be present.

**[lex.float.2]** The fraction requires a digit after the `.`: `1.` followed by anything
else is the integer `1` and a `.` token. So `1..2` is a range and `1.Max(2)` is a
method call.

**[lex.float.3]** An exponent with no digits (`1e`, `1e+`) is **E0007**. An integer suffix
on a float (`1.5i32`) or a float suffix on a non-decimal literal (`0b1f32`) is **E0008**.

Tests: `tests/golden/lexer/numbers.envo`.

### 1.7.3 Character literals

```
CharLiteral = "'" ( ~( "'" | '\' | LF | CR ) | Escape ) "'"
```

**[lex.char.1]** A character literal contains exactly one Unicode scalar value, written
directly or as an escape. `''` and `'ab'` are **E0009**. A literal not closed on the same
line is **E0005**, reported at the opening quote.

Tests: `tests/golden/lexer/strings.envo`, `tests/spec/01-lexical/e0005_*.envo`, `e0009_*.envo`.

### 1.7.4 String literals

```
StringLiteral = '"' ( ~( '"' | '\' | LF | CR ) | Escape )* '"'
```

**[lex.str.1]** A string literal may not contain a raw line break (LF or CR). A string
not closed on its line is **E0004**, reported at the opening quote.

**[lex.str.2]** The literal's value is the UTF-8 text between the quotes with escapes
replaced.

**[lex.str.3]** `"""` always begins a **raw string literal** (multi-line, no escapes,
C# 11 rules: the closing `"""` sets the indentation to remove). Raw strings are specified
in full when the Stage 2 lexer implements them (M3).

**[lex.str.4]** `$"` begins an **interpolated string**: `$"Hello, {name}!"`. Inside it,
`{` starts an expression hole closed by the matching `}`; `{{` and `}}` are literal
braces; an optional `:format` may end a hole. Interpolated strings are specified in full
in chapter 3 (§3.2.4).

**Core:** raw strings are **E0902** and interpolated strings are **E0901**.

Tests: `tests/golden/lexer/strings.envo`, `tests/spec/01-lexical/e0004_*.envo`.

### 1.7.5 Escapes and control characters

| Escape | Meaning |
|---|---|
| `\n` `\r` `\t` | LF, CR, tab |
| `\0` | U+0000 |
| `\\` `\'` `\"` | backslash, quote, double quote |
| `\xHH` | the ASCII character with hex value `HH`, which must be ≤ `7F` |
| `\u{H…}` | the Unicode scalar value with 1–6 hex digits |

**[lex.esc.1]** Any other character after `\` is **E0006**. So is `\x` without two hex
digits, or with a value above `7F` (use `\u{…}` for non-ASCII text).

**[lex.esc.2]** `\u{…}` must have braces and 1–6 hex digits, and must name a Unicode
scalar value (≤ 10FFFF and not D800–DFFF). Otherwise **E0010**.

**[lex.esc.3]** Control characters U+0000–U+001F (except tab) and U+007F may not appear
raw inside character or string literals: **E0011**. Write them as escapes.

Tests: `tests/golden/lexer/strings.envo`, `tests/spec/01-lexical/e0006_*.envo`, `e0010_*.envo`, `e0011_*.envo`.

### 1.7.6 Boolean and null literals

`true`, `false` and `null` are keywords (§1.6.1) that act as literals.

## 1.8 Punctuation and operators

**[lex.punct.1]** Punctuation is lexed by **maximal munch**: at each position the longest
spelling in this table that matches is taken.

| Length | Tokens |
|---|---|
| 3 | `<<=` `>>=` `..=` `??=` `+%=` `-%=` `*%=` |
| 2 | `==` `!=` `<=` `>=` `&&` `\|\|` `<<` `>>` `+=` `-=` `*=` `/=` `%=` `&=` `\|=` `^=` `=>` `->` `::` `..` `??` `++` `--` `+%` `-%` `*%` |
| 1 | `+` `-` `*` `/` `%` `=` `<` `>` `!` `~` `&` `\|` `^` `?` `:` `;` `,` `.` `(` `)` `[` `]` `{` `}` |

**[lex.punct.2]** When the parser expects `>` to close a generic argument list and the
current token is `>>`, `>=` or `>>=`, it consumes only the first `>` and leaves the rest
(`>`, `=`, `>=`) as the next token. This is the only place a token is split.

**[lex.punct.3]** There is no `?.` token. `a?.b` lexes as `a`, `?`, `.`, `b`, and means
`(a?).b` (chapter 3).

**[lex.punct.4]** `$` and `#` are not tokens on their own: `$` must begin `$"` and `#`
must begin a directive (§1.9) or the shebang. Any other character that starts no token
is **E0002**.

Tests: `tests/golden/lexer/punctuation.envo`, `tests/golden/lexer/munch.envo`.

## 1.9 Directives

**[lex.dir.1]** `#` at the start of a line (after optional whitespace) begins a
compile-time directive: `#if`, `#elif`, `#else`, `#endif`. Conditions are typed Envo
constant expressions (`#if target.os == "windows"`), not string macros. Directives are
specified with conditional compilation (chapter 4, §4.9).

**Core:** directives are **E0903**.

## 1.10 End of file

**[lex.eof.1]** The token sequence always ends with one **end-of-file** token, positioned
just past the last byte. An empty file produces only that token at 1:1.
Tests: `tests/golden/lexer/empty.envo`.

## 1.11 Stage 0 behaviour (informative)

Stage 0 lexes Envo-Core only, but reserves every keyword and lexes every operator above
so that no Envo-Core program means something different in full Envo. It stops at the
first lexical error. Its `lex` command prints one line per token:

```
<line>:<col> <n|s|j> <class> <text>
```

`class` is `kw`, `punct`, `ident`, `int`, `float`, `char`, `string` or `eof`. For `kw`
and `punct`, `text` is the token kind's canonical spelling (from the kind table, not the
source), so the dump also checks that each spelling maps to the right kind. For the
other classes `text` is the source text.
