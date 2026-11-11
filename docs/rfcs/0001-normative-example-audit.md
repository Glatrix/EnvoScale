# RFC 0001: Normative example audit (§3.3)

- **Status:** Accepted (2026-11-11). The owner asked for open decisions to follow the
  brief's core principles; "no hidden copies, no hidden allocations" (brief §3.6) decides C1 and C2.
- **Author(s):** founding engineer
- **Affects:** language (chapters 2, 3, 5), the founding brief's §3.3 examples
- **Tracking:** must be resolved before Stage 2 type checking (M3)

## Summary

The founding brief calls the §3.3 syntax tour "normative examples; the spec must make
these work". Writing chapters 1–5 against them turned up two examples that cannot
type-check under the brief's own rules, and several that needed a design decision to
parse at all. This RFC lists each one and proposes a resolution. The parse decisions are
already reflected in the draft spec; the two type errors need the owner's agreement
because they change the examples themselves.

## Motivation

Brief §0.7: "When this document is ambiguous or impossible as written, stop and write
an RFC describing the conflict and your proposed resolution, instead of quietly
deviating." Normative examples that silently fail to compile would make the conformance
suite either lie or fail forever.

## The conflicts

### C1. `Largest<T>` moves a non-`Copy` value out of a borrow — needs a change

```envo
public T Largest<T>(in Span<T> items) where T : IComparable<T> {
    var best = items[0];
    foreach (var it in items) if (it > best) best = it;
    return best;
}
```

`items` is a shared borrow. `return best;` returns an owned `T`, which means either
moving out of the borrowed span (forbidden: [own.move.3]) or copying a `T` that is not
known to be `Copy` (forbidden: "no hidden copies of non-Copy types", brief §3.6).

**Proposed resolution:** add the `Copy` constraint, which is what the function actually
needs:

```envo
public T Largest<T>(in Span<T> items) where T : IComparable<T>, Copy {
```

With [own.borrow.4] (a `var` initialized from a borrowed place binds a borrow), a
borrowing variant also works for non-`Copy` types:

```envo
public in T Largest<T>(in Span<T> items) where T : IComparable<T> { … }
```

### C2. `ReadConfig` returns a borrow of a local as an owned `string` — needs a change

```envo
public Result<string, IoError> ReadConfig(in string path) {
    var text = fs.ReadText(path)?;
    return Ok(text.Trim());
}
```

If `Trim()` returns a `str` view (the zero-allocation choice), the result borrows
`text`, which is dropped at the end of the function. If `Trim()` returns a new `string`,
it allocates, which is fine but should be visible.

**Proposed resolution:** `string` gets an in-place, consuming `Trimmed(this)` that
reuses the buffer (no allocation), and the example uses it:

```envo
    return Ok(text.Trimmed());
```

`Trim()` keeps returning a `str` view for the common non-owning case.

### C3. `await http.Get(url)?.Text()` — resolved in the draft spec

With C#'s prefix `await`, this awaits the result of `.Text()` applied to a future.
**Resolution adopted** in [expr.await.1]: `await` covers every async call in its
operand (Swift's model), so the example means "await Get, propagate, await Text".

### C4. `?` as propagation vs. conditional vs. nullable type — resolved in the draft spec

`string? FindUser(…)`, `fs.ReadText(path)?`, and `id == 1 ? "ada" : null` all use `?`.
**Resolution adopted** in [lex.flags.*], [type.opt.1] and [expr.q.1]: a `?` joint with
the previous token is postfix (type suffix or propagation); a `?` with a space before it
is the conditional operator. There is no `?.` token.

### C5. Missing semicolons in builder blocks and the gallery — resolved in the draft spec

The Lumen level-2 example separates builder statements by line breaks, and the CLI
gallery entry has no trailing `;`. **Resolution adopted** in [stmt.term.*]: line
breaks end complete statements; `;` is optional before `}` and at end of file.

### C6. `get("/") => "…"` and `page("/") => Landing(…)` — resolved in the draft spec

These are not lambdas (`get("/")` is not a parameter list). **Resolution adopted** in
[expr.trail.2]: inside a builder block, `call => expr` passes `() => expr` as the
call's last argument.

### C7. `Shape` variant patterns are unqualified — resolved in the draft spec

`match this { Circle(_, r) => … }` uses `Circle` without `Shape.`. **Resolution
adopted** in [expr.match.2]: variants of the scrutinee's enum type are in scope in
patterns.

## Drawbacks

C1 and C2 change text the brief calls normative. The alternative, adding implicit
copies or implicit allocation, would contradict brief §3.6 ("no hidden copies of
non-Copy types", "no hidden allocations"), which is also normative and more fundamental.

## Alternatives

- **Implicit `Clone` for `IComparable` types.** Rejected: hidden cost, surprising for
  large `T`.
- **Make `Trim()` allocate.** Viable, but hides an allocation behind a method that
  usually doesn't need one.
- **Keep the examples and mark them "non-compiling illustrations".** Rejected: the brief
  explicitly makes them normative.

## Prior art

Rust (`Copy` bounds; `trim()` returning `&str`), Swift (`await` covering an expression;
whitespace-sensitive `?`), Kotlin and Swift (newline statement termination, trailing
lambdas), C# (`?` and `?:`).

## Unresolved questions

None. C1 and C2 are accepted as proposed: the corrected examples are the normative ones.
When Stage 2 type-checks them (M3), `tests/spec/` gets the brief's original versions as
`expect-error` tests (E0502 for C1, E0504 for C2) and the corrected versions as passing tests.

## Migration / edition impact

None: no Envo code exists yet.
