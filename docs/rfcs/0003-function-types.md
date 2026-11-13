# RFC 0003: Function and closure types

- **Status:** Accepted (2026-11-11). Under the owner's standing instruction to decide open
  design questions by the brief's core principles: two doors (a single `fn(…)` type for
  beginners, closure kinds and C function pointers for experts), zero-cost pipelines
  (brief §3.3), and Rust's memory model with fewer things to write.
- **Author(s):** founding engineer
- **Affects:** language (chapters 1, 2, 3 and 5, Envo-S1); not Envo-Core
- **Tracking:** [#30](https://github.com/envoscale/EnvoScale/issues/30), milestone M2.
  Implemented by Stage 1 in M2.9 (function values for every position; see
  [`architecture/stage1.md`](https://github.com/envoscale/EnvoScaleAsm/blob/main/docs/stage1.md), "Closures"); `extern "C" fn` is
  not part of Envo-S1 and comes with Stage 2.

## Summary

Function types are written `fn(A, B) -> R` (or `fn(A)` when nothing is returned). Every
lambda has its own anonymous type; it converts to any `fn` type it matches. A `fn` type
used as a **parameter** makes the function generic over the closure, so passing a lambda
costs nothing; anywhere else a `fn` type is a **function value**: a code pointer and an
owned environment. Closures come in three kinds, `fn`, `mut fn` and `once fn`, which say
whether calling one may change or use up what it captured. `extern "C" fn(…)` is a plain C
function pointer. `move` before a lambda captures everything by move.

## Motivation

Chapter 3 defines lambdas (`x => e`) and the brief's pipelines need them
(`orders.Where(o => o.Paid)`), but no type can be written for one, so no function can
take a lambda, no struct can store a callback, and Stage 1 cannot type-check closures
(M2.9). `docs/PLAN.md` open question 4 and chapter 3's "`move` prefix — reserved word
TBD" both wait on this RFC.

The design has to serve both doors at once:

- a beginner writes `void Each(List<int> xs, fn(int) f)` and calls it with any lambda,
  including one that counts into a local variable;
- the standard library writes `Where` so that the lambda is inlined, with no allocation
  and no indirect call;
- systems code passes callbacks to C;
- the borrow checker can prove that a closure never outlives what it borrows and that
  two callers never mutate the same captured state at once.

## Guide-level explanation (the simple door)

A lambda is a small function written inline:

```envo
var doubled = numbers.Select(n => n * 2);
int total = 0;
numbers.Each(n => total += n);       // the lambda may change `total`
```

To accept a lambda, give the parameter a function type: `fn`, the parameter types in
parentheses, and `->` with the result type. Leave out `-> R` when nothing is returned.

```envo
void Each(in List<int> items, mut fn(int) action) {
    foreach (var it in items) action(it);
}

List<int> Keep(in List<int> items, fn(int) -> bool test) { … }
```

`fn` means the function only *reads* what it captured. `mut fn` means it may *change*
it, like `total += n` above. (`once fn` is for functions that can be called only once;
you rarely need it.) If you pass a lambda that changes something to a parameter that
only allows `fn`, the compiler says so and shows the change.

To keep a function for later, store it in a field. It keeps what it captured alive:

```envo
struct Button {
    string Label;
    mut fn() OnClick;
}

int clicks = 0;
var b = new Button { Label = "Go", OnClick = move () => clicks++ };
b.OnClick();
```

`move` makes the lambda take its own copy of everything it uses, which is what a stored
function needs. (Here `b` owns a copy of `clicks`; to share a counter between several
functions, use a `class`.)

## Reference-level explanation (the full-control door)

### Syntax

```
FnType     = [ "mut" | "once" ] "fn" "(" [ FnParam { "," FnParam } ] ")" [ "->" Type ]
           | "extern" StringLiteral "fn" "(" [ FnParam { "," FnParam } ] ")" [ "->" Type ]
FnParam    = [ "in" | "ref" | "out" ] Type
Lambda     = [ "move" ] LambdaHead "=>" ( Expr | Block )
LambdaHead = Identifier | "(" [ LambdaParam { "," LambdaParam } ] ")"
LambdaParam = [ "in" | "ref" | "out" ] [ Type ] Identifier
```

- **[fn.syn.1]** `fn`, `mut`, `once` and `move` are **contextual keywords** (§1.6.2):
  `fn` only where a type is expected and followed by `(`; `mut` and `once` only directly
  before such a `fn`; `move` only directly before a lambda. Elsewhere they are ordinary
  identifiers, so every Envo-Core program stays valid ([core.subset.1]).
- **[fn.syn.2]** `->` binds to the nearest `fn` and associates to the right:
  `fn(int) -> fn(int) -> int` is a function returning a function. `fn(int) -> int?` returns
  an optional `int`; an optional function is written `(fn(int) -> int)?`, where the
  parentheses group a single type.
- **[fn.syn.3]** A missing `-> R` means `-> void`.

### Types and kinds

- **[fn.type.1]** Each lambda expression has its own **closure type**: an anonymous
  struct holding its captures, which cannot be named. Each named function has its own
  **function item type** with no captures.
- **[fn.type.2]** A closure type has a **kind**, inferred from the lambda's body:
  - `fn`: the body only reads its captures;
  - `mut fn`: the body mutates a capture, or calls a `mut fn` capture;
  - `once fn`: the body moves a captured value out, or calls a `once fn` capture.

  Kinds nest: every `fn` is also a `mut fn`, and every `mut fn` is also a `once fn`.
  Function items are `fn`.
- **[fn.type.3]** Calling needs access that matches the kind: a `fn` can be called
  through any access, including a shared (`in`) borrow; a `mut fn` needs owned or
  exclusive (`ref`) access (calling it through a shared borrow is **E0332**); a
  `once fn` needs ownership and is moved by the call, so a second call is E0501.
- **[fn.type.4]** A function type `K fn(P…) -> R` (with kind `K`) **matches** a closure or
  function item when their parameter types and modes are the same, their result types are
  the same, and the closure's kind is `K` or nested inside it ([fn.type.2]). There is no
  other variance. A lambda whose kind is too strong for the target is **E0331**, which
  points at the capture that is changed or moved.

### Where a function type appears

- **[fn.pos.1] Parameters: generic.** A parameter whose type is a function type
  (`fn(int) -> bool test`, `in fn(int) test`, `ref mut fn() f`) makes the function
  generic over the argument's closure type, as if it had a hidden type parameter `F`
  with the constraint `where F : fn(int) -> bool`. Each closure type gets its own
  instantiation (monomorphization, [type.gen.1]), so the call is direct and can be
  inlined, and nothing is allocated. The parameter mode applies as usual: by value moves
  or copies the closure into the callee, `in` borrows it, `ref` borrows it exclusively.
- **[fn.pos.2] Constraints.** A function type may be used as an interface constraint:
  `where F : mut fn(T) -> bool`. This is the explicit spelling of [fn.pos.1] and is how
  the standard library writes pipelines.
- **[fn.pos.3] Everywhere else: function values.** In fields, locals with a written
  type, return types, array elements and generic arguments (`List<fn(int)>`), a function
  type is a **function value**: two words, a code pointer and an environment pointer. A
  closure converts to a function value that it matches ([fn.type.4]); its captures move
  into a heap-allocated environment owned by the value, unless it has no captures, in
  which case the environment pointer is null and nothing is allocated. Function values
  are moved (not `Copy`) and drop their environment.
- **[fn.pos.4] Dynamic dispatch.** A function value implements its own function type, so
  it can be passed to a generic parameter ([fn.pos.1]); the call then goes through the
  code pointer. This is the one way to get dynamic dispatch, and it is visible in the
  type.
- **[fn.pos.5] C function pointers.** `extern "C" fn(P…) -> R` is a single code pointer
  with the C calling convention: `Copy`, no environment, safe to pass to and receive from
  C. Named functions declared `extern "C"`, and lambdas with no captures, convert to it.
  Calling one received from foreign code needs `unsafe`, like any foreign call.

### Captures

- **[fn.cap.1]** A lambda captures each local variable of an enclosing function that its
  body uses. The capture mode is inferred, in this order: by **move** if the lambda is
  prefixed with `move`, if the body moves the variable, or if the closure converts to a
  function value or is returned (it escapes); otherwise by **exclusive borrow** if the
  body mutates the variable; otherwise by **shared borrow**. A `Copy` value captured by
  move is copied. This refines chapter 3 §3.2.6.
- **[fn.cap.2]** A closure that borrows its captures holds those borrows for as long as it
  is live. The borrow rules of chapter 5 apply to them: while a closure exclusively
  borrows `total`, `total` cannot be used directly ([own.borrow.1]), and a closure cannot
  outlive what it borrows (E0504). A closure or function value with borrowed captures has
  an implicit lifetime parameter, like a struct with borrowed fields ([own.life.2]).
- **[fn.cap.3]** `this` is captured like any other variable.
- **[fn.cap.4]** A closure type is `Copy` when it captures nothing by move, or only `Copy`
  values by move. It is `Sendable` and `Shareable` when its captures are
  ([own.thread.1]), which is what lets `spawn(move () => …)` be checked.

### Lambda typing

- **[fn.lam.1]** A lambda's parameter types and modes come from its target function type
  (the parameter, field or variable it is assigned to) when there is one; otherwise every
  parameter must have a written type (E0330: "cannot infer the type of `x`").
- **[fn.lam.2]** The result type comes from the target; with no target it is the type of
  the expression body, or of the `return` statements of a block body (all the same type,
  E0317).
- **[fn.lam.3]** A lambda cannot name itself. Recursive helpers are written as named
  functions.

### Representation (ABI)

- **[fn.abi.1]** A closure type is laid out as a struct of its captures (borrowed captures
  are pointers). Its code takes a pointer to that struct as a hidden first argument, before
  `this` and the declared parameters.
- **[fn.abi.2]** A function value is `{ code: *void, env: *void }`, 16 bytes on 64-bit
  targets. A non-null `env` points to a heap block whose first word is a pointer to the
  closure's drop routine, followed by the captures. Function items and capture-free
  closures use a null `env`; calls still pass it, and their code ignores it.
- **[fn.abi.3]** The layout of closure types and function values is unspecified to Envol
  code except through `extern "C" fn`, which is exactly a C function pointer.

### Errors

| Code | Message |
|---|---|
| E0330 | cannot infer the type of lambda parameter `x`; write its type |
| E0331 | this lambda changes (or moves) `x`, but `F` must be a `fn` (or `mut fn`) |
| E0332 | `f` is a `mut fn`, so calling it needs `ref` or owned access, not a shared borrow |

Mismatched parameter or result types are E0301; calling a `once fn` twice is E0501.

### Tests

With M2.9: run tests for each position ([fn.pos.1]–[fn.pos.5]) and each kind, captures
by borrow and by move, a `mut fn` counter, a `once fn` that moves a capture, function
values stored in a struct and in an array, a capture-free value with no allocation
(checked through `--emit eir`), and `extern "C" fn` round-tripping through the platform
shim; type-error tests for E0330–E0332, E0301 and E0501; borrow tests for [fn.cap.2]
once the borrow checker exists (M2.10).

## Drawbacks

- The same spelling means a generic parameter in one position and a function value in
  another. This is Rust's `impl Fn` in argument position; it is what makes the simple
  door free, and the explicit `where F : …` spelling is always available.
- Three kinds are more than C# has. Beginners only meet `mut fn` when the compiler tells
  them, and the error points at the exact change.
- Monomorphizing every lambda parameter grows code size. The optimizer can merge
  identical instantiations, and a function value parameter avoids it when wanted.

## Alternatives

- **C# delegates, `Func<A, R>` and `Action<A>`.** Familiar, but the result comes last,
  unlike every Envol declaration, the arity is fixed per type name, and delegates are
  always heap-allocated and dynamically dispatched.
- **Rust's three traits only, `F: Fn(A) -> R`, plus `Box<dyn Fn>`.** Precise, but the
  simple door would need generics and boxes to take a callback.
- **One kind, with dynamic exclusivity checks** (Swift). Simpler to write, but the checks
  cost time and turn compile-time errors into run-time panics.
- **Reserving `fn`, `mut`, `once` and `move`.** Would break Envo-Core programs that use
  them as names and need a Stage 0 lexer change.

## Prior art

Rust (`Fn`/`FnMut`/`FnOnce`, closure kind inference, `impl Trait` in argument position,
`move` closures); Swift (`(Int) -> Bool`, `@escaping`); C# (`Func`/`Action`, lambda
syntax, `delegate* unmanaged` for C function pointers); C++ (lambdas with unique types).

## Unresolved questions

- `Clone()` for function values whose captures are all clonable: needs a clone routine in
  the environment header. Later, if wanted.
- Method groups as values (`list.Each(print)` works, because `print` is a function item;
  `list.Each(p.Draw)` binding a receiver needs a lambda for now).
- `async` lambdas, with `async`/`await` (M4+).

## Migration / edition impact

None. All new words are contextual, and the new syntax was not valid before.
