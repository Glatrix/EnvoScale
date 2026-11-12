# Stage 2 (`envoc`)

`envoc` is the self-hosting compiler (M3). Until it reaches a fixed point it is written in
Envo-S1 and built by `envoc1` (PLAN D16). This page grows with each increment of PLAN §5.

## Build

```
envoc0 (assembly) → envoc1 (Envo-Core) → envoc (Envo-S1)
```

Both bootstrap scripts build `build/stage2/envoc.exe` and `build/stage2/envoc` with
`envoc1`, from the files in `compiler/files.txt` (the first is the entry file). CI checks
that the Linux-host and Windows-host builds are byte-identical.

## Layout

Each file starts with a namespace: `envoc.util` (support code), `envoc.diag` (sources and
errors), `envoc.syntax` (lexer and parser), and more per pass as they land. The entry
file, `driver/main.envo`, is in the root namespace.

## Support code (M3.1)

On top of the S1 prelude (`List<T>`, `string`, `Option`, `Result`):

- `envoc.util`: `Same`, `StartsWith`, `Decimal`, `Hash` (FNV-1a), `StrMap<V>` (open
  addressing), `ReadFile`, and `Take`, which empties a list into a new one (a field can't
  be moved out of a value whose type has a drop).
- `envoc.diag`: the source files, line and column lookup, and errors in the shared format,
  `path:line:col: error[E####]: message` (exit 1) or `envoc: error: message` (exit 2).

## Lexer (M3.2)

`envoc.syntax.Lex` turns one file into a `List<Token>`. Tokens are plain data, so the list
doesn't borrow the text. Keyword and punctuation tables (`LexTables`) are built once per
run. Like the earlier stages, it stops at the first error, and `--core` reports Core's
leave-outs as E0901–E0904 instead of E0950.

The test suites compare `envoc lex` with `envoc1 lex` on every `.envo` file in the repo, in
addition to the lexer goldens and lexical spec tests. During development the two were also
compared on 4,200 randomly mutated files. That found one bug: a punctuation lookup sliced
three bytes, which can end mid-character, and Stage 2's `str` slices check character
boundaries. `tests/spec/01-lexical/e0904_after_punct.envo` covers it.

## Parser (M3.3)

`envoc.syntax.Parse` is a port of Stage 1's recursive descent, rule for rule, so trees and
first errors match. It works as methods on a `Parser` that owns the token and node lists
and hands them back as a `Tree`. Nodes keep Stage 1's layout (`node.envo`), which keeps
the parse dump identical. Backtracking restores the position, the node count and any
`>>` tokens split while trying a generic type.

It is tested like the lexer: the parser goldens, the syntax spec tests, and `envoc parse`
against `envoc1 parse` on every `.envo` file in the repo. Comments aren't kept in the tree
yet; the formatter (M5) needs that.

## Checker (M3.4)

`envoc.sema` ports Stage 1's checker (`bootstrap/stage1/check/`) function for function, as
methods on a `Checker` that owns the syntax tree and its side tables. `envoc check` prints
the same typed tree and reports the same first error as `envoc1 check`. Stage 1's runtime
and prelude are embedded as `driver/runtime.envo`, generated with `envoc1 embed` (the tests
check it is current).

Type and symbol names are `Text` values, a pointer and a length, rather than `str`: a `str`
is a borrow, and tables that own their entries cannot hold one. The text they point to
(source files, string literals, and names the checker builds and keeps in `Owned`) lives
as long as the checker.

## Ownership (M3.5)

The move checker (`move.envo`), call borrows and closure origins (`borrow.envo`) and
storage summaries (`summary.envo`) follow Stage 1's. The per-function state (`MoveCx`,
its snapshots and loop frames, `OriginCx`) is owned data passed `ref` next to the
`Checker`. Stage 2 accepts and rejects exactly what Stage 1 does; accepting what chapter 5
allows beyond that is increment 3.10, after the fixed point.

## EIR (M3.6)

`envoc.eir` holds EIR v1 in memory (`ir.envo`), the text reader, the canonical printer
and the verifier, ported from Stage 1. `envoc eir-check` matches `envoc1 eir-check` on the
EIR goldens and error tests, and on the whole-program EIR `envoc1 eir` writes for every run
program and for Stage 2 itself (1.7 MB).

Lowering (`eir/lower*.envo`, namespace `envoc.lower`) is a port of Stage 1's `lower/`. It
emits instructions, slots, struct types and globals in the same order, so `envoc eir`
prints the same module as `envoc1 eir`.

## Backend (M3.6)

`envoc.x64` is Stage 1's `-O0` code generator: the encoder (`asm.envo`), the code
generator (`gen.envo`) and the PE and ELF writers (`image.envo`). `envoc build` writes the
same bytes as `envoc1 build` for every run and multi-file program, both targets. The tests
run each Stage 2 build and compare it with Stage 1's.

Stage 2 also builds Stage 1 and itself exactly as `envoc1` does, so at `-O0`, `envoc`
built by `envoc` is byte-identical to `envoc` built by `envoc1`.

## Objects and linking (M3.7)

`binary.envo` reads and writes the binary form of EIR ([eir.bin]). `envoc eir-check`
reads either form; `-o` writes binary, and so does `envoc eir -o`.

An object (`.eo`) is the binary EIR of the whole program, in which only its own unit's
functions have bodies:

```
envoc compile a.envo b.envo --unit a.envo -o a.eo     # a's code; the runtime goes with the entry file
envoc compile a.envo b.envo --unit b.envo -o b.eo
envoc link a.eo b.eo -o program
```

Each object still checks every file, because Stage 2 has no interface files yet; it
lowers the whole program and turns the other units' functions into declarations.
Generic instances, closures and thunks stay in every object. `envoc link` takes the
first object and gives each declaration the body another object defines. All objects
come from the same lowering, so types, globals and functions have the same indexes in
each, and the linker checks that they do. The result is the module `envoc build` makes,
so the executable is byte-identical. The tests check that for every run program, for
each multi-file program linked unit by unit, and for Stage 2 itself.

Interface files, which let a unit compile without the other units' sources, come with
the build system (M5).

## The fixed point (M3.9)

```
envoc1 --build--> stage2a (build/stage2) --build -O2--> stage2b --build -O2--> stage2c
```

`bootstrap fixedpoint` builds stage2b and stage2c for both targets and requires them to
be byte-identical (D18). stage2a and stage2b run different code (`envoc1`'s and `-O2`'s),
so their outputs may differ; stage2b and stage2c are the same compiler built by itself.
In CI, `fixed-point-linux` and `fixed-point-windows` run it on each host, and
`fixed-point` compares the two hosts' stage2c byte for byte, so the fixed point is the
same on both.

## -O2 (M3.8)

`-O2` (for `build`, `compile`, `link`, `eir` and `eir-check`) runs EIR passes and a
better backend. The passes are inlining of small functions, constant folding, branch
folding, copy propagation, dead-code elimination and block merging; see
`compiler/opt/README.md`. The backend adds rematerialization, linear-scan register
allocation and unrolled small copies; see `compiler/backend/x86_64/README.md`. The
verifier checks the result.

The tests build and run every run and multi-file program at `-O2` as well and expect the
same output, exit code and panic. They also build Stage 2 at `-O2` and use that compiler
to build Stage 2 again: at `-O0` it must write the same bytes as `envoc1`, and at `-O2`
it must reproduce itself.

The `-O2` compiler builds Stage 2 in about 2.3 s, against 3.9 s for the `-O0` one, on
the development machine. Most of what remains is the checker: name lookup scans every
`use` declaration and builds a joined name per scope it tries, as Stage 1's does. That is
an algorithm to change later, not something `-O2` can fix.

`ComputeDoms` in the verifier, a port of Stage 1's, recomputed every block's successors
for every pair of blocks on each pass. Stage 2 now builds the predecessor lists once,
which took a self-build from 6.5 s to 3.9 s. The dominator sets, and therefore the
results, are the same.

## Stage 1 bugs found by Stage 2

Stage 2 is the largest Envo-S1 program, so it finds `envoc1` bugs. Each is fixed in
Stage 1 with a test before Stage 2 moves on (PLAN §6).

| Found in | Bug | Test |
|---|---|---|
| M3.1 | A `match` binding in a loop kept the previous iteration's "moved" state | `s1-run/match_in_loop.envo` |
| M3.1 | A generic body lowered for a type with a drop, then one without, reused stale drop flags | `s1-run/generic_drops.envo` |
| M3.1 | Views: method results were assumed to borrow the receiver, and a view made from a local pointer was treated as a view of the pointer. Stage 1 now works out which storage each function's result views | `s1-run/views.envo`, `s1-own/` |
| M3.3 | Backtracking after a type didn't undo a `>>` split into two `>`, so `List<List<u32>> F()` at top level failed to parse | `s1-run/nested_generics.envo` |
| M3.4 | Any read of a variable in an argument conflicted with the same call's `ref` borrow of it, so `list.Push(list.Len())` was E0503. Arguments are evaluated before the call takes its borrows, so a read that yields a value holding no borrow is now fine; lending a view or a `string`-as-`str` still conflicts. Chapter 5 now says so ([own.borrow.2]) | `s1-run/two_phase_args.envo`, `s1-own/e0503_ref_and_read.envo`, `s1-own/e0503_ref_and_string_view.envo` |
