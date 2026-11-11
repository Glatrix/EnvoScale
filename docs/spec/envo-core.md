# Envo-Core

> **Status:** Draft; being implemented by Stage 0 (`envoc0`, milestone M1).
> Lexical part implemented and tested; parser, checker and code generator next.

Envo-Core is the small subset of Envo that the assembly compiler `envoc0` accepts. It
exists for one reason: to write Stage 1 (`envoc1`) in something nicer than assembly
while keeping Stage 0 small enough to audit (target: under ~15k lines of `.eas`).

## 1. The subset property

**[core.subset.1]** Every program `envoc0` accepts is a syntactically valid Envo program,
and where full Envo also accepts it, it means the same thing. Core only ever *removes*
features; it never adds syntax or changes meaning.

**[core.subset.2]** Full Envo may reject some Core programs, because Stage 0 does not
check borrow rules (chapter 5). Stage 1's source is required to pass both compilers once
Stage 2 exists; CI enforces this from M3.

Consequences that shaped Core:

- All Envo keywords are reserved in Core, even ones Core does not use.
- Core's borrowed string type is `str`, not `string` (which is owned in Envo).
- Raw pointer dereference needs `unsafe { }` in Core, as in Envo.
- Character literals have type `char` in Envo; Core has no `char`, so it only allows
  ASCII character literals where a `u8` is expected, which Envo also allows (§2.3).

## 2. Lexical structure

Chapter 1 applies in full, with these restrictions (all reported by the lexer):

| Not in Core | Error |
|---|---|
| Interpolated strings `$"…"` | E0901 |
| Raw strings `"""…"""` | E0902 |
| Directives `#if` … | E0903 |
| Non-ASCII characters outside literals and comments | E0904 |

Float literals lex normally and are rejected by the parser (E0905).

## 3. Types

| Type | Notes |
|---|---|
| `i8` `i16` `i32` `i64` `u8` `u16` `u32` `u64` `isize` `usize` | and the aliases `byte` `int` `uint` `long` `ulong` |
| `bool` | |
| `str` | pointer + length, immutable UTF-8. String literals have this type |
| `void` | return type only |
| `T[N]` | fixed array, `N` an integer constant |
| `T[]` | slice: pointer + length |
| `*T` | raw pointer; deref inside `unsafe` |
| `struct` types | fields only |
| `enum` types | fieldless; optional `: u8`/`u16`/`u32`/`u64`/`i…` representation (default `i32`) |

Not in Core: floats, `char`, `i128`/`u128`, tuples, `T?`, `Result`, classes,
interfaces, generics, function types (E0905 "not part of Envo-Core" for each).

All Core types are `Copy`. Struct layout in Core is C layout (declaration order, natural
alignment), which is a valid choice of the unspecified default layout.

## 4. Items

```envo
const usize MAX_TOKENS = 1 << 20;

static usize tokenCount = 0;         // globals: allowed, discouraged

enum TokenKind : u16 { Eof, Ident, Int }

struct Token {
    TokenKind Kind;
    u32 Start;
    u32 Len;
}

i64 Add(i64 a, i64 b) {
    return a + b;
}
```

- Functions: `ReturnType Name(Type a, Type b) { … }` or `=> expr;`. No generics, default
  or named arguments, `in`/`ref`/`out` modes, receivers, `async` or `extern`.
- `struct` with fields. `public`/`private` are accepted and have no effect (one module).
- `enum`, fieldless.
- `const` and `static` items.
- **Top-level statements** in the entry file (the first file on the command line) form
  `main`. `return n;` at top level sets the exit code.
- No `namespace` or `use`: all files passed to `envoc0` form one program with a single
  global scope. Duplicate names are an error.

## 5. Statements and expressions

Statements:

- `var x = e;`, `T x = e;`, `T x;` (zero-initialized)
- expression statements, assignment `=` and compound assignment (`+=` … `>>=`, `+%=` …)
- `x++;` `x--;`
- `if (c) … else …`, `while (c) …`, `for (init; cond; step) …`
- `break;` `continue;` `return e;` `return;`
- `match e { arms }` in **statement form** only: arms are
  `pattern => statement-or-block`, patterns are integer constants, enum variant names,
  `A | B` alternatives, and `_`
- blocks `{ … }` and `unsafe { … }`

Expressions:

- literals: integers (with suffixes), `true`, `false`, ASCII character literals (as `u8`),
  strings (as `str`)
- names, calls `f(a, b)`, field access `s.f`, indexing `a[i]` (bounds-checked),
  `s.Len` and `s.Ptr` on slices and `str`
- unary `-` `!` `~`, `*p` (unsafe), `&x` (unsafe; yields `*T`)
- binary `* / % *% + - +% -% << >> & ^ | == != < > <= >= && ||` with chapter 3's
  precedence
- `e as T` between integer types, `bool`→integer, enum→integer, pointer↔`usize`,
  and pointer→pointer (unsafe)
- `sizeof(T)`, `alignof(T)`
- `new T { Field = e, … }` struct literals

Semicolons: required after each statement except directly before `}` or at end of file
(§3.1).

Integer overflow, division by zero and out-of-range indexing panic (exit code 101), as
in full Envo.

## 6. Built-in functions

Core programs have no standard library. These built-ins are always in scope:

| Built-in | Meaning |
|---|---|
| `void print(str s)` | write `s` and a newline to stdout |
| `void write(i32 fd, str s)` | write `s` to fd 0/1/2 or an opened file |
| `isize read(i32 fd, *u8 buf, usize n)` | read up to `n` bytes; 0 at end of file, negative on error |
| `i32 open(str path, i32 mode)` | mode 0 = read, 1 = write (create/truncate), 2 = write executable; negative on error |
| `void close(i32 fd)` | |
| `*u8 alloc(usize n)` | zeroed, 16-byte-aligned memory from a process-wide arena; never freed |
| `void exit(i32 code)` | flush output and exit |
| `usize argc()` | number of command-line arguments |
| `str arg(usize i)` | argument `i` (0 is the program) |
| `void panic(str msg)` | print `panic: msg` to stderr and exit with code 101 |

These map one-to-one onto the Stage 0 platform shim (`sys_*` routines), which is why
porting Stage 0 is a matter of one platform file.

## 7. Command line

```
envoc0 lex <file.envo>                              print the token stream (implemented)
envoc0 build <entry.envo> [more.envo…] -o <out>     compile (M1, not yet implemented)
        [--target x86_64-windows | x86_64-linux]
envoc0 version | help
```

Exit codes: 0 success, 1 compile errors, 2 usage error, 70 internal error
(e.g. out of memory).

## 8. Limits

Stage 0 is allowed simple fixed limits, reported clearly when hit: source files up to
16 MiB each. Other limits will be listed here as the parser and code generator land.
