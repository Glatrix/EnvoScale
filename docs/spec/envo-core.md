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

### 5.1 Grammar (normative; implemented by `bootstrap/stage0/src/parser.eas`)

Notation as in [the spec README](README.md#conventions). Terminals in capitals are token
classes from chapter 1 (`IDENT`, `INT`, `CHAR`, `STRING`, `EOF`).

```
Program     = ( Item | Statement )* EOF
Item        = Visibility? ( Function | Struct | Enum | Const | Static )
Visibility  = 'public' | 'private'
Function    = Type IDENT '(' Params? ')' ( Block | '=>' Expr End )
Params      = Param ( ',' Param )* ','?
Param       = Type IDENT
Struct      = 'struct' IDENT '{' Field* '}'
Field       = Visibility? Type IDENT End
Enum        = 'enum' IDENT ( ':' Type )? '{' ( Variant ( ',' Variant )* ','? )? '}'
Variant     = IDENT ( '=' Expr )?
Const       = 'const' Type IDENT '=' Expr End
Static      = 'static' Type IDENT ( '=' Expr )? End

Type        = '*' Type | IDENT TypeSuffix*
TypeSuffix  = '[' ']' | '[' ( INT | IDENT ) ']'

Statement   = Block | 'unsafe' Block
            | 'if' '(' Expr ')' Statement ( 'else' Statement )?
            | 'while' '(' Expr ')' Statement
            | 'for' '(' Simple? ';' Expr? ';' Simple? ')' Statement
            | 'match' Expr '{' Arm* '}'
            | 'break' End | 'continue' End | 'return' Expr? End
            | Simple End
Simple      = 'var' IDENT '=' Expr
            | Type IDENT ( '=' Expr )?                 (declaration; see [core.decl.1])
            | Expr ( AssignOp Expr | '++' | '--' )?
AssignOp    = '=' | '+=' | '-=' | '*=' | '/=' | '%=' | '&=' | '|=' | '^='
            | '<<=' | '>>=' | '+%=' | '-%=' | '*%='
Arm         = Pattern ( '|' Pattern )* '=>' ( Block ','? | Simple ( ',' | before '}' ) )
Pattern     = '_' | Prefix
Block       = '{' Statement* '}'
End         = ';' | before '}' | before EOF

Expr        = Binary(1)
Binary(p)   = Cast ( BinOp(q) Binary(q + 1) )*        for each operator with level q >= p
Cast        = Prefix ( 'as' Type )*
Prefix      = ( '-' | '!' | '~' | '*' | '&' ) Prefix | Postfix
Postfix     = Primary ( '(' Args? ')' | '[' Expr ']' | '.' IDENT )*
Args        = Expr ( ',' Expr )* ','?
Primary     = INT | CHAR | STRING | 'true' | 'false' | IDENT | '(' Expr ')'
            | 'sizeof' '(' Type ')' | 'alignof' '(' Type ')'
            | 'new' Type '{' ( Init ( ',' Init )* ','? )? '}'
Init        = IDENT '=' Expr
```

Binary operator levels, lowest first: 1 `||`; 2 `&&`; 3 `== != < > <= >=`;
4 `|`; 5 `^`; 6 `&`; 7 `<< >>`; 8 `+ - +% -%`; 9 `* / % *%`. All are left-associative
except level 3, which does not associate.

**[core.decl.1]** A statement starting with something that parses as a `Type` followed
by an `IDENT` and then `=`, `;`, `}` or end of file is a declaration; otherwise it is an
expression statement. So `u8[16] buf;` declares and `buf[i] = 1;` assigns. At top level,
`Type IDENT (` begins a function.

**[core.syntax.1]** Syntax errors are **E0101**, worded `expected X, found Y`.

**[core.syntax.2]** A comparison whose left operand is an unparenthesized comparison
(`a < b < c`) is **E0102**.

**[core.syntax.3]** The target of an assignment, `++` or `--` must be a name, a field
access, an index or a dereference (`*p`); anything else is **E0103**.

**[core.syntax.4]** Statements and expressions may nest at most 256 levels deep; deeper
nesting is **E0104**. A statement, an expression, a prefix operator, and each operator,
cast, call, index or member access in a chain (`a + b + c`, `x.y.z`) counts as a level,
because those chains form left-deep trees that later passes walk recursively. In
practice a single expression can hold roughly 250 chained binary operators. (A Stage 0
limit, so no input can overflow its stack.)

**[core.syntax.5]** Full-Envo syntax that Core leaves out is **E0905**, naming the
construct, wherever the parser can recognise it: any reserved keyword outside the Core
set (`class`, `foreach`, `null`, `this`, `in`, `ref`, …; the Core set is
`_ alignof as break const continue else enum false for if match new private public
return sizeof static struct true unsafe var while`), float literals, `?`, `??`, `=>`
outside functions and arms, `..`, `::`, `->`, `??=`, named arguments (`f(x: 1)`),
tuples and array literals, generic parameters on functions, default parameter values,
struct base lists, enum payloads, and local `const`, `static`, `struct` and `enum`.

The AST is printed by `envoc0 parse <file>`; its format is described in
[`tests/golden/README.md`](../../tests/golden/README.md).

### 5.2 Names and types (normative; implemented by `bootstrap/stage0/src/check.eas`)

`envoc0 check <file>` runs these rules and prints the tree with types (format in
`tests/golden/README.md`). Errors use E02xx (names), E03xx (types) and E0905.

**Scopes.**

- **[core.name.1]** Program scope holds every item (function, struct, enum, const, static),
  the primitive type names and their aliases (§3), and the built-ins (§6). Items may be
  used before they are declared. Defining a name twice in program scope is **E0201**.
  This includes redefining a primitive type name, an alias or a built-in.
- **[core.name.2]** Each function body, and the top-level statements together, have their own
  local scope. Top-level locals are not visible inside functions. Blocks nest. A local may
  not reuse the name of a parameter or of another local that is still in scope (**E0204**);
  it may shadow a program-scope name.
- **[core.name.3]** An unknown type name is **E0202**; an unknown value name is **E0203**.
  Using a value where a type is needed is **E0208**, and a type where a value is needed is
  **E0209** (except `Enum.Variant`).
- **[core.name.4]** Duplicate fields, parameters or enum variants are **E0201**.

**Types.**

- **[core.type.1]** `T[N]` needs `N` to be a constant (§5.3) of any integer type with a value
  ≥ 0 (**E0311**). `void` may only be a function's return type (**E0327** elsewhere).
- **[core.type.2]** Structs are laid out in declaration order with natural alignment: each field
  is placed at the next multiple of its alignment, and the size is rounded up to the
  largest alignment (1 for an empty struct). A struct that contains itself by value,
  directly or through other structs or arrays, is **E0303**. A type larger than
  2³¹ − 1 bytes is **E0312**.
- **[core.type.3]** Sizes and alignments: `bool`, `i8`, `u8` are 1; `i16`, `u16` are 2;
  `i32`, `u32` are 4; `i64`, `u64`, `isize`, `usize` and pointers are 8; `str` and slices
  are 16 (pointer, then length) with alignment 8; `T[N]` is `N × size(T)` with `T`'s
  alignment; an enum has its representation type's layout (default `i32`).
- **[core.type.4]** An enum's representation must be an integer type (**E0324**). Variants
  without a value take the previous value plus one (the first takes 0). Values are
  constants that must fit the representation (**E0304**) and must be distinct (**E0323**).

**Expressions.** Each expression is checked against an *expected type*, which may be absent.

- **[core.expr.1]** An integer literal has its suffix's type. Without a suffix it takes the
  expected type if that is an integer type, and otherwise `i32`. A value that does not fit
  is **E0304**. A character literal has type `u8` and must be ASCII (E0905 otherwise). A
  string literal has type `str`. `true` and `false` have type `bool`.
- **[core.expr.2]** An expression whose type differs from the expected type is **E0301**.
  There are no implicit conversions. Only an unsuffixed integer literal adapts, possibly
  through `-`, `~`, parentheses and arithmetic, bitwise and shift operators whose
  operands are all such literals.
- **[core.expr.3]** For `+ - * / % +% -% *% & | ^`, both operands must have the same integer
  type, which is the result type. If one operand is an unsuffixed literal expression, it
  takes the other operand's type. For `<< >>`, the left operand determines the result
  type; the right operand may have any integer type. A non-integer operand is **E0302**.
- **[core.expr.4]** `== !=` compare two operands of the same integer, `bool`, enum or pointer
  type. `< > <= >=` compare integers. `&& || !` take `bool`. The result is `bool`.
  Unary `-` needs a signed integer; `~` any integer.
- **[core.expr.5]** `*p` needs a pointer and gives its element type; `&x` needs a place
  (§5.1 [core.syntax.3]) and gives a pointer to its type (**E0316** otherwise). Both
  need `unsafe` (**E0306**).
- **[core.expr.6]** `a[i]` works on arrays, slices and `str` (giving `u8`), and on pointers
  inside `unsafe`. The index may have any integer type; an unsuffixed literal index is
  `usize`.
- **[core.expr.7]** `s.F` names a struct field. On a pointer to a struct it dereferences
  first and needs `unsafe`. `x.Len` (`usize`) and `x.Ptr` (`*u8` for `str`, `*T` for
  `T[]`) work on `str` and slices. `E.V` names a variant of enum `E`. Anything else is
  **E0206**.
- **[core.expr.8]** A call's callee must name a function or built-in. Anything else is
  **E0314**; a function used as a value is E0905. A wrong argument count is **E0307**.
  Each argument is checked against its parameter type.
- **[core.expr.9]** `e as T` converts between integer types, from `bool` or an enum to an
  integer, and between a pointer and `usize`/`isize` or another pointer type (the
  pointer conversions need `unsafe`). Anything else is **E0305**. `sizeof(T)` and
  `alignof(T)` are `usize` constants.
- **[core.expr.10]** `new S { F = e, … }` needs a struct type. Each field may be set at
  most once (**E0207**); fields that are not set are zero. The result has type `S`.
- **[core.expr.11]** A value of type `void` can only be an expression statement
  (**E0322** elsewhere).

**Statements.**

- **[core.stmt.1]** `var x = e` gives `x` the type of `e` (an unsuffixed literal makes it
  `i32`). `T x = e` checks `e` against `T`; `T x;` is zero-initialized.
- **[core.stmt.2]** An expression statement must be a call (**E0321**).
- **[core.stmt.3]** The target of `=`, `+=`, … `++`, `--` must be a mutable place: a local, a
  static, a field or element of one, or `*p` (in `unsafe`). Elements of `str` and of
  slices are read-only, and so are constants, functions and `.Len`/`.Ptr` (**E0315**).
  Compound operators follow [core.expr.3]; `++`/`--` need an integer.
- **[core.stmt.4]** Conditions of `if`, `while` and `for` must be `bool`.
- **[core.stmt.5]** `break` and `continue` must be inside a loop (**E0205**).
- **[core.stmt.6]** In a function returning `T`, `return e` checks `e` against `T`, and
  `return;` is **E0317**. In a `void` function `return e` is **E0317**. Top-level `return e`
  checks `e` against `i32` (the exit code). A non-`void` function whose end is reachable
  is **E0320**. A statement *terminates* if it is a `return`; a call to `exit` or `panic`; a
  block containing a terminating statement; an `if` with an `else` whose branches both
  terminate; a `while (true)` loop with no `break` for that loop; or an exhaustive
  `match` whose arms all terminate.
- **[core.stmt.7]** `match` needs an integer or enum scrutinee. Patterns are constants of
  the scrutinee's type; for an enum, bare variant names refer to its variants. A value
  that appears twice is **E0319**. Without `_`, an enum `match` must name every variant
  and an integer `match` is not exhaustive (**E0308**).

### 5.3 Constants

- **[core.const.1]** A constant expression is built from integer literals, character
  literals, string literals (constants of type `str`), `true`/`false`, names of `const` items, enum variants, `sizeof`, `alignof`,
  parentheses, unary `- ~ !`, the binary operators other than `&& ||`, and `as` between
  integer types. Anything else, where a constant is required, is **E0311**.
- **[core.const.2]** Constants are evaluated at compile time in their own type. Overflow,
  division by zero, and shifts by at least the bit width are **E0310**. A `const` whose
  value depends on itself is **E0309**.
- **[core.const.3]** `const` initializers, `static` initializers, array sizes, enum values
  and `match` patterns are constants. (Statics are placed in the executable's data with
  their initial value; Stage 0 runs no code before `main`.)

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
envoc0 parse <file.envo>                            print the syntax tree (implemented)
envoc0 check <file.envo>                            check names and types; print the typed tree (implemented)
envoc0 build <entry.envo> [more.envo…] -o <out>     compile (M1, not yet implemented)
        [--target x86_64-windows | x86_64-linux]
envoc0 version | help
```

Exit codes: 0 success, 1 compile errors, 2 usage error, 70 internal error
(e.g. out of memory).

## 8. Limits

Stage 0 is allowed simple fixed limits, reported clearly when hit: source files up to
16 MiB each. Other limits will be listed here as the parser and code generator land.
