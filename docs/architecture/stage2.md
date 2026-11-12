# Stage 2 architecture (`envoc`)

`envoc` is the self-hosting compiler (milestone M3). Until it compiles itself to a fixed
point it is written in **Envo-S1** and built by `envoc1` (PLAN D16); afterwards it may use
any Envo it compiles. This page records its design as it is built, increment by increment
(PLAN §5). File-by-file contents are in [`compiler/README.md`](../../compiler/README.md).

## Build

```
envoc0 (assembly) ──builds──► envoc1 (Envo-Core) ──builds──► envoc (Envo-S1)
```

Both bootstrap scripts build `envoc` with the native `envoc1` for Windows and Linux
(`build/stage2/envoc.exe`, `build/stage2/envoc`) from `compiler/files.txt`, whose first file
is the entry file. CI uploads both builds from both hosts, and the `reproducible` job
requires them to be byte-identical, as for Stages 0 and 1.

## Source layout

Every Stage 2 file starts with a namespace: `envoc.util` (support library), `envoc.diag`
(sources and diagnostics), and one per pass as they arrive (`envoc.syntax`,
`envoc.sema`, …), in the folders `compiler/README.md` lists. The entry file,
`driver/main.envo`, is in the root namespace and imports what it uses.

## Support library (M3.1)

Stage 2 builds on the S1 prelude (`List<T>`, `string`, `Option`, `Result`) and adds:

- `envoc.util`: `Same`, `StartsWith`, `Decimal`, `Hash` (FNV-1a) and `StrMap<V>`, a hash map
  from strings to values with open addressing over two `List`s.
- `envoc.diag`: the source files read (`Sources`), positions (line and column, columns
  counting characters), and diagnostics in the format every stage shares:
  `path:line:col: error[E####]: message` with exit code 1, and `envoc: error: message`
  with exit code 2 for command-line problems.

## Stage 1 bugs found by Stage 2

Stage 2 is the largest Envo-S1 program, so it finds `envoc1` bugs. Each gets a minimal
reproduction in `tests/spec/s1-*` and a fix in Stage 1 before Stage 2 goes on (PLAN §6):

| Found in | Bug | Test |
|---|---|---|
| M3.1 | A `match` binding inside a loop kept the previous iteration's "moved" state | `s1-run/match_in_loop.envo` |
| M3.1 | One generic body lowered for a type with a drop and then one without reused the first instance's drop flags (a miscompilation, caught by the EIR verifier) | `s1-run/generic_drops.envo` |
| M3.1 | Views: a method's result was assumed to borrow its receiver whenever it could hold a borrow, and a view built from a local pointer was taken for a view of the pointer local; Stage 1 now summarizes which storage each function's result views, and a local's freezes end with the locals that hold the views | `s1-run/views.envo`, `s1-own/` |

## Decisions

PLAN D16–D20 fix the language Stage 2 is written in, its relation to Stage 1 (the same
EIR v1; Stage 1's semantics first), the fixed point (D18), linking over EIR objects (D19)
and the two optimization levels (D20). Their details are filled in here as the
increments that implement them land.
