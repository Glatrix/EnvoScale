# 3. Expressions and Statements

> **Status:** Draft. Stage 0 implements the Envo-Core subset (M1); the rest follows in
> Stage 1–2. Tests: none yet (M1 adds `tests/spec/03-expressions/`).

## 3.1 Statement termination

Envo accepts C#-style semicolons and also lets line breaks end statements, so builder
blocks read naturally (`Stack { NavBar(…) Hero(…) }` across lines).

**[stmt.term.1]** A statement ends at `;`, at the `}` that closes its block, at end of
file, or at a line break (a token with the newline-before flag, §1.5) **if** the
statement is complete there and the next token cannot continue it.

**[stmt.term.2]** A line break does **not** end a statement when the next line starts
with a binary operator (other than `-`, `&`, `*`, which are also prefix operators),
`.`, `?`, `:`, `=>`, `)`, `]`, `,`, `else`, `where`, or `as`. So method chains may
continue on the next line:

```envo
var total = orders
    .Where(o => o.Paid)
    .Sum();
```

**[stmt.term.3]** A `(` or `[` at the start of a line never continues the previous line
as a call or index; it starts a new statement.

**[stmt.term.4]** Semicolons are never required before `}` or at end of file. This is why
`print("Hello, World!")` is a complete program.

**Core:** Envo-Core requires `;` after every statement except immediately before `}` or
end of file. Such programs are valid under the full rules.

## 3.2 Primary expressions

### 3.2.1 Literals and names
Literals (§1.7), names (`x`, `math.PI`), `this`, `null`, `()` (the `void` value).

### 3.2.2 Parenthesized and tuple expressions
`(e)` groups; `(a, b)` builds a tuple; `(x: 1, y: 2)` builds a named tuple.

### 3.2.3 Collection literals
`[1, 2, 3]` is an array literal whose type comes from context (`T[N]`, `List<T>`, `T[]`
of static data). A trailing comma is allowed.

### 3.2.4 Interpolated strings
`$"Total: {sum:0.00} ({count} items)"` evaluates each hole and formats it through
`IFormattable`. Holes may contain any expression, including nested strings. `{{` / `}}`
are literal braces. The result is a `string` unless the target type is a formatting
sink (e.g. `print`'s parameter), in which case it is written directly with no
intermediate allocation.

### 3.2.5 Object creation
`new T(args)` calls a constructor; `new T { Field = v, … }` initializes fields;
`new()` / `new() { … }` takes `T` from the target type (`List<Node> Children { get; } = new();`).

### 3.2.6 Lambdas
`x => e`, `(x, y) => e`, `(int x) => { … }`, `() => e`. Captures are inferred: by shared
borrow if only read, by exclusive borrow if mutated, by move if the lambda escapes (or
with an explicit `move` prefix — reserved word TBD in RFC).

## 3.3 Postfix expressions

| Form | Meaning |
|---|---|
| `f(a, b, name: c)` | call, with optional named arguments |
| `f(ref x)`, `f(out var y)` | passing to `ref` / `out` parameters must be marked at the call site; `in` is implicit |
| `a[i]` | index (bounds-checked) |
| `a.b` | member access; auto-borrows and auto-dereferences |
| `e?` | propagation: on `Err(e)` / `None`, return it from the current function (converting the error with `IFrom`); otherwise unwrap |
| `f(args) { … }` / `f { … }` | call with a **trailing block** (see §3.8) |

**[expr.q.1]** `?` is **postfix propagation** when it is joint with the previous token
(no space before it), and the **conditional operator** when it has a space before it.
So `f()?` propagates, and `a ? b : c` is a conditional. A joint `?` followed by an
expression on the same line, as in `a?b : c`, is an error with a suggestion.

**[expr.q.2]** `a?.b` is `(a?).b` (there is no null-conditional operator; §1.8). For
optional chaining that does not return early, use `a.Map(x => x.b)`.

## 3.4 Operators and precedence

From highest to lowest:

| Level | Operators | Associativity |
|---|---|---|
| 1 | postfix: call, index, `.`, `?` | left |
| 2 | prefix: `-` `!` `~` `*` (deref, `unsafe`) `&` (address-of, `unsafe`) `await` | right |
| 3 | `as` | left |
| 4 | `*` `/` `%` `*%` | left |
| 5 | `+` `-` `+%` `-%` | left |
| 6 | `<<` `>>` | left |
| 7 | `&` | left |
| 8 | `^` | left |
| 9 | `\|` | left |
| 10 | `==` `!=` `<` `>` `<=` `>=` `is` | **non-associative** |
| 11 | `&&` | left |
| 12 | `\|\|` | left |
| 13 | `??` | right |
| 14 | `..` `..=` | non-associative |
| 15 | `c ? a : b` | right |
| 16 | `=>` (lambda) | right |

**[expr.prec.1]** Bitwise operators bind tighter than comparisons, so `x & 1 == 0`
means `(x & 1) == 0`. (This differs from C and C#, on purpose.)

**[expr.prec.2]** Comparisons do not chain: `a < b < c` is an error.

**[expr.op.1]** Operators on user types call interfaces (`IAdd`, `ISub`, …,
`IEquatable`, `IComparable`), statically dispatched.

**[expr.op.2]** `&&`, `||` and `??` short-circuit.

## 3.5 `await`

**[expr.await.1]** `await e` covers **every** async call inside `e`: each is awaited where
it occurs, left to right. So

```envo
async Result<string, NetError> Fetch(string url) => await http.Get(url)?.Text();
```

awaits `http.Get(url)`, propagates its error with `?`, then awaits `.Text()`.
Calling an async function outside an `await`-covered expression is an error; to get a
task without waiting for it, use `async { … }` or `spawn(…)`.

*Rationale:* prefix `await` (C#) applied to a postfix chain needs parentheses at every
step; postfix `.await` (Rust) is unfamiliar to C# users. Swift's rule, where one `await`
marks a whole expression, keeps the C#-looking syntax and makes the example above mean
what it reads as. (Decision D7 in `docs/PLAN.md`.)

## 3.6 `match` and patterns

```envo
f32 Area() => match this {
    Circle(_, r)  => math.PI * r * r,
    Rect(a, b)    => (b.X - a.X) * (b.Y - a.Y),
};
```

**[expr.match.1]** `match` is an expression. Arms are `pattern (if guard)? => expr`,
separated by `,` or line breaks. Matching must be **exhaustive**; the compiler lists
missing cases.

**[expr.match.2]** When the scrutinee's type is an enum, its variant names are in scope
inside patterns without qualification (`Circle`, not `Shape.Circle`).

**[expr.match.3]** In the scrutinee position, a name followed by `{` is never parsed as
a trailing-block call: `match x { … }` matches `x`.

Patterns: literals, `_`, bindings (`r`), variants with positional or named payloads,
tuples, ranges (`'a'..='z'`), alternatives (`A | B`), and `x is Pattern` as a boolean
test anywhere an expression is allowed.

## 3.7 Conditional, loop and jump statements

```envo
if (cond) stmt else stmt
while (cond) stmt
do stmt while (cond);
for (init; cond; step) stmt
foreach (var x in xs) stmt
label: while (…) { … break label; }
return e;  break;  continue;
```

**[stmt.cond.1]** Conditions are parenthesized (as in C#) and must have type `bool`;
there is no truthiness.

**[stmt.if.1]** `if` is also an expression when both branches are present and the
`if` appears in expression position: `var x = if (a) 1 else 2;`.

**[stmt.inc.1]** `x++` and `x--` are statements, not expressions; they cannot appear
inside another expression.

**[stmt.assign.1]** Assignment (`=`, `+=`, …) is a statement-level expression of type
`void`, so `if (x = 5)` is a type error and `a = b = c` is not allowed.

## 3.8 Trailing blocks and builders

Trailing blocks are what make the one-line hello worlds possible:

```envo
window("Hello") { Text("Hello, World!") }
serve(8080) { get("/") => "Hello, World!" }
scene { cube().Spin(); light.Sun(); }
```

**[expr.trail.1]** `f(args) { body }` passes `body` as a final **builder** argument to
`f`. `f { body }` is the same with no other arguments. The callee's last parameter
declares the builder type, which decides how statements in `body` are collected
(e.g. each expression statement adds a child view).

**[expr.trail.2]** Inside a builder body, the statement `g(args) => e` passes a lambda
`() => e` as the final argument of `g`: `get("/") => "Hello"` is
`get("/", () => "Hello")`.

**[expr.trail.3]** A `{` on a new line after a complete call does **not** attach as a
trailing block.

## 3.9 `unsafe`, `comptime` and `asm` blocks

- `unsafe { … }` allows raw pointer dereference, `&` address-of, calls to `unsafe`
  functions, inline `asm`, and unchecked intrinsics. `envo audit unsafe` lists every one.
- `comptime { … }` and `const` expressions run at compile time on the EIR interpreter.
- `asm x86_64 { … }` contains assembly in `.eas` instruction syntax, using Envo tokens
  and Envo comments, with `{name}` operand bindings and a clobber list. Only valid
  inside `unsafe`.

## 3.10 Envo-Core

**Core:** Envo-Core has literals, names, calls, indexing, field access, unary
`- ! ~ *`, `&` (address-of), `as`, binary arithmetic/bitwise/comparison/logical
operators (including `+% -% *%`), assignment and compound assignment, `x++`/`x--`,
`sizeof(T)`, struct literals `new T { … }`, `if`/`else`, `while`, `for`, `break`,
`continue`, `return`, statement-form `match` on integers and enums, and `unsafe`
blocks. See [`envo-core.md`](envo-core.md).
