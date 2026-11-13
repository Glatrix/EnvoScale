# The compiler (`envoc`)

`envoc` compiles itself. It is written in Envo-S1, the subset the stage 1 compiler in
[EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm) accepts, so that it can still
be built up from assembly. It was called "Stage 2" while that chain was being built, and
much of this page and the code's comments still say so; `envoc0` and `envoc1` are stages 0
and 1, which now live in EnvoScaleAsm.

## Build

```
seed envoc --build--> build/envoc-seeded --build -O2--> build/envoc --build -O2--> the same bytes
```

`build.sh build` downloads a seed compiler built by EnvoScaleAsm, builds the compiler
from `compiler/files.txt` (the first is the entry file) with it, and builds it again with
the result, for Windows and Linux. `build.sh test` checks that `build/envoc` rebuilds
itself into the same bytes, and CI checks that the Linux-host and Windows-host builds are
byte-identical. EnvoScaleAsm checks the other direction: that the compiler built by stage 1
behaves exactly as the one built by itself.

## Layout

Each file starts with a namespace: `envoc.util` (support code), `envoc.diag` (sources and
errors), `envoc.syntax` (lexer and parser), and more per pass as they land. The entry
file, `driver/main.envol`, is in the root namespace.

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

The test suites compare `envoc lex` with `envoc1 lex` on every `.envol` file in the repo, in
addition to the lexer goldens and lexical spec tests. During development the two were also
compared on 4,200 randomly mutated files. That found one bug: a punctuation lookup sliced
three bytes, which can end mid-character, and Stage 2's `str` slices check character
boundaries. `tests/spec/01-lexical/e0904_after_punct.envol` covers it.

## Parser (M3.3)

`envoc.syntax.Parse` is a port of Stage 1's recursive descent, rule for rule, so trees and
first errors match. It works as methods on a `Parser` that owns the token and node lists
and hands them back as a `Tree`. Nodes keep Stage 1's layout (`node.envol`), which keeps
the parse dump identical. Backtracking restores the position, the node count and any
`>>` tokens split while trying a generic type.

It is tested like the lexer: the parser goldens, the syntax spec tests, and `envoc parse`
against `envoc1 parse` on every `.envol` file in the repo. Comments aren't kept in the tree
yet; the formatter (M5) needs that.

## Checker (M3.4)

`envoc.sema` ports Stage 1's checker (`bootstrap/stage1/check/`) function for function, as
methods on a `Checker` that owns the syntax tree and its side tables. `envoc check` prints
the same typed tree and reports the same first error as `envoc1 check`. Stage 1's runtime
and prelude are embedded as `driver/runtime.envol`, generated with `envoc1 embed` (the tests
check it is current).

Type and symbol names are `Text` values, a pointer and a length, rather than `str`: a `str`
is a borrow, and tables that own their entries cannot hold one. The text they point to
(source files, string literals, and names the checker builds and keeps in `Owned`) lives
as long as the checker.

## Ownership (M3.5)

The move checker (`move.envol`), call borrows and closure origins (`borrow.envol`) and
storage summaries (`summary.envol`) follow Stage 1's. The per-function state (`MoveCx`,
its snapshots and loop frames, `OriginCx`) is owned data passed `ref` next to the
`Checker`. Up to the fixed point Stage 2 accepted and rejected exactly what Stage 1
does.

### Beyond Stage 1 (M3.10)

Stage 2 now accepts some programs chapter 5 allows and Stage 1 rejects. Each has a test
in `tests/spec/s2-run/` that Stage 2 builds and runs, and that names the error `envoc1`
still gives:

- **Disjoint field borrows** (`disjoint_fields.envol`). A call may borrow different fields
  of one local, `F(ref p.A, ref p.B)`. Each use carries its field path, and two uses
  conflict only when one path is a prefix of the other.
- **Partial moves out of values that need a drop** (`partial_moves.envol`). A field may be
  moved out of a local whose type needs a drop, unless the type has its own `Drop`. Such
  a local (`SF_PARTLY`) gets a drop flag per field that needs one. Moving the field
  clears its flag (NMove 3 on the member), assigning the field sets it again, and the
  local is dropped field by field. Flags go one level deep, so moving `o.I.A` is still
  E0502.

- **`once fn` lambdas** (`once_fn.envol`). A lambda whose type is `once fn` and that
  owns its captures may move them out. Calling a `once fn` uses it up.
- **`once fn` inferred** ([fn.type.2], issue #79; `once_fn_inferred.envol`). A lambda with
  no target type (`var f = () => { … };`) whose body moves out a capture is a `once fn`.
  The kind must be known before the variable's uses are checked, so `CheckLambda` runs a
  quiet move check of the body alone (`LambdaMovesCapture`) once the body's types are
  known; only moves of the lambda's own captures count. A lambda with a `fn` or `mut fn`
  target that moves a capture is still E0502, as is a borrowing lambda (one passed to a
  function-typed parameter without `move`); an inferred `once fn` passed where a `fn` is
  expected is E0301 (`s2-own/e0501_inferred_once_twice.envol`,
  `s2-own/e0301_inferred_once_as_fn.envol`).

- **Locals that borrow** (`borrow_locals.envol`). `var x = place;` without a type, where
  taking the value would move out of a borrow (an array element, an element of a shared
  view, a value behind an `in` or `ref` local), binds `x` as a read-only borrow, as a
  `foreach` element is ([own.borrow.4]). Lowering makes `x` the place's address. The
  place's local cannot change or move until `x`'s last use. An element of a `mut T[]` is
  not borrowed this way, since the view could change it.

- **Borrows end at their last use** ([own.borrow.2], issue #79). A view or a borrowing
  local frees what it borrows after its last use, not at the end of its block. The move
  check runs twice over each function: a quiet first pass numbers the statements and
  notes each local's last use; the second ends a borrow before the first statement after
  it. A use inside a loop lasts to the end of the loop; a local a lambda captures, or one
  another kept borrow rests on, keeps its borrow to the end of its block
  (`s2-run/borrow_last_use.envol`, `s2-own/e0503_view_*.envol`).
- **Views kept by calls.** A value that views a local, passed to a call that can change
  a local able to hold views (a `ref` receiver or `ref` argument of a type that holds
  borrows, or a generic instance such as `List<str>` whose type arguments do), is kept
  there: that local now views it (`s2-own/e0503_view_kept_in_list.envol`). Before M13 a
  view pushed into a list declared in an outer block could outlive its source. A bare
  type parameter is not counted (generic code that fills a buffer through `ref T` would
  otherwise never compile), so a view passed into a `ref T` inside generic code is not
  tracked yet: a known gap, closed when instances are checked one by one.


## EIR (M3.6)

`envoc.eir` holds EIR v1 in memory (`ir.envol`), the text reader, the canonical printer
and the verifier, ported from Stage 1. `envoc eir-check` matches `envoc1 eir-check` on the
EIR goldens and error tests, and on the whole-program EIR `envoc1 eir` writes for every run
program and for Stage 2 itself (1.7 MB).

Lowering (`eir/lower*.envol`, namespace `envoc.lower`) is a port of Stage 1's `lower/`. It
emits instructions, slots, struct types and globals in the same order, so `envoc eir`
prints the same module as `envoc1 eir`.

## Backend (M3.6)

`envoc.x64` is Stage 1's `-O0` code generator: the encoder (`asm.envol`), the code
generator (`gen.envol`) and the PE and ELF writers (`image.envol`). `envoc build` writes the
same bytes as `envoc1 build` for every run and multi-file program, both targets. The tests
run each Stage 2 build and compare it with Stage 1's.

Stage 2 also builds Stage 1 and itself exactly as `envoc1` does, so at `-O0`, `envoc`
built by `envoc` is byte-identical to `envoc` built by `envoc1`.

## Objects and linking (M3.7)

`binary.envol` reads and writes the binary form of EIR ([eir.bin]). `envoc eir-check`
reads either form; `-o` writes binary, and so does `envoc eir -o`.

An object (`.eo`) is the binary EIR of the whole program, in which only its own unit's
functions have bodies:

```
envoc compile a.envol b.envol --unit a.envol -o a.eo     # a's code; the runtime goes with the entry file
envoc compile a.envol b.envol --unit b.envol -o b.eo
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

The seed and the compiler it builds run different code, so their outputs may differ; the
compiler built by the seed's build and the one it builds are the same compiler built by
itself, and must be byte-identical (D18). `build.sh test` checks it for both targets, and
CI compares the two hosts' builds byte for byte.

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

The `-O2` compiler builds Stage 2 in about 1.8 s on the development machine (2.9 s
before the M3 performance sweep), and `envoc1` builds it in 1.9 s (3.75 s before). The
sweep was guided by a sampling profiler over `envoc build -map` output. It found these:
- `HasParams` recomputed for every query; it is now worked out once per type, when the
  type is stored.
- `HoldsBorrow` walked struct fields on every call; it is now cached per type.
- `OpTable` rebuilt an opcode's record through a 60-arm `match` on every call; it now
  comes from a table built on first use.
- Stage 1's verifier had the quadratic dominator computation Stage 2 had already fixed.
- `string.Append` and `Reserve` in the prelude copied byte by byte; they now copy eight
  bytes at a time.

About a quarter of a build is now the operating system creating the output executable,
which is outside the compiler.

`ComputeDoms` in the verifier, a port of Stage 1's, recomputed every block's successors
for every pair of blocks on each pass. Stage 2 now builds the predecessor lists once,
which took a self-build from 6.5 s to 3.9 s. The dominator sets, and therefore the
results, are the same.

## Stage 1 bugs found by Stage 2

Stage 2 is the largest Envo-S1 program, so it finds `envoc1` bugs. Each is fixed in
Stage 1 with a test before Stage 2 moves on (PLAN §6).

| Found in | Bug | Test |
|---|---|---|
| M3.1 | A `match` binding in a loop kept the previous iteration's "moved" state | `s1-run/match_in_loop.envol` |
| M3.1 | A generic body lowered for a type with a drop, then one without, reused stale drop flags | `s1-run/generic_drops.envol` |
| M3.1 | Views: method results were assumed to borrow the receiver, and a view made from a local pointer was treated as a view of the pointer. Stage 1 now works out which storage each function's result views | `s1-run/views.envol`, `s1-own/` |
| M3.3 | Backtracking after a type didn't undo a `>>` split into two `>`, so `List<List<u32>> F()` at top level failed to parse | `s1-run/nested_generics.envol` |
| M3.4 | Any read of a variable in an argument conflicted with the same call's `ref` borrow of it, so `list.Push(list.Len())` was E0503. Arguments are evaluated before the call takes its borrows, so a read that yields a value holding no borrow is now fine; lending a view or a `string`-as-`str` still conflicts. Chapter 5 now says so ([own.borrow.2]) | `s1-run/two_phase_args.envol`, `s1-own/e0503_ref_and_read.envol`, `s1-own/e0503_ref_and_string_view.envol` |
| M3.10 | Calling a `once fn` did not use it up, so it could be called twice ([fn.type.3]) | `s1-own/e0501_once_fn_twice.envol` |
| M3 sweep | Functions and statics were named in EIR without their namespace, so two `Show`s in different namespaces made one EIR name: `eir` text and objects of such a program failed to verify (a build still worked, since calls go by index). EIR names now carry the namespace (`envoc.util.Same`) | `s1-multi/same_names/` |
| M4 | A top-level variable with a built-in's name (`str print`) hid the built-in in other functions: lowering looked the callee up again after checking and found the variable. The checker now records the built-in on the call | `core-run/builtin_shadowed.envol` |
