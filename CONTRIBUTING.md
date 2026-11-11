# Contributing to EnvoScale

Thank you for helping. EnvoScale is meant to last for decades, so the rules below
favour things that stay true over things that are quick.

## Licensing of contributions

EnvoScale is dual-licensed (free Community License, paid commercial licenses; see
[`LICENSING.md`](LICENSING.md)). Every contribution must be made under the
[Contributor License Agreement](CLA.md): say in your first pull request that you agree to
it. Pull requests without that statement are not merged.

## Ground rules

1. **Original work only.** Study any codebase, paper or spec you like, then write your
   own implementation. Never paste code from another project. Published specs and
   official test vectors are welcome, with attribution (see `tests/vectors/`).
2. **No third-party dependencies.** Not in the compiler, not in `lib/`, not in tools.
   OS and hardware interfaces are reached only through `adapters/`.
3. **Never fake completion.** No functions that pretend to succeed. Unfinished work gets
   `TODO(M<n> or #<issue>): reason` in the code and a line in [`STATUS.md`](STATUS.md).
4. **A feature without tests does not exist.**
5. **Comments explain *why*, not *what*.** Design decisions go in
   `docs/architecture/` or an RFC.

## Where code may live

- `lib/**` may import only `lib/**`. Importing anything from `adapters/**` is a build error.
- `adapters/<kind>/<name>/` may import `lib/**` and its own folder only.
- Every module folder has a `README.md` (purpose, simple door, full-control door,
  ports used, stability tier), its source, a `tests/` folder and an `examples/` snippet.

## Making a change

1. For anything touching the language, EIR, a stable API, a port interface, or the
   charter, write an RFC first (`docs/rfcs/0000-template.md`).
2. Make one logical change per commit, using
   [Conventional Commits](https://www.conventionalcommits.org/):
   `feat(compiler/opt): add LICM pass`, `fix(stage0/lexer): reject 0b102`,
   `docs(spec): clarify newline termination`.
3. Run the checks:
   - Windows: `.\bootstrap.ps1 check` then `.\bootstrap.ps1 test`
   - Linux/macOS: `./bootstrap.sh check` then `./bootstrap.sh test`
   (Once the `envo` CLI exists, `envo test` replaces these.)
4. Update `STATUS.md` if your change moves a subsystem forward or back.

## Tests

| Kind | Where | Format |
|---|---|---|
| Spec tests | `tests/spec/<chapter>/` | `.envo` files with `// expect: <output>` or `// expect-error: E0042` (optionally `@ line:col`) |
| Golden tests | `tests/golden/<tool>/` | input file + expected output file side by side |
| Unit tests | next to the code, in `tests/` | per module |
| Conformance | `tests/conformance/` | one suite per port |
| Bootstrap | `tests/bootstrap/` | stage equivalence and fixed-point checks |

Spec tests run in both AOT and script modes once both exist; the outputs must be identical.

## Pre-merge checklist (from §18 of the brief)

- [ ] No third-party code or packages were introduced.
- [ ] No `lib/**` → `adapters/**` imports.
- [ ] Simple door and full-control door both exist for any new public API.
- [ ] Tests added and passing in AOT and script modes. Fixed-point check passes if `compiler/` changed.
- [ ] Docs, examples, and `STATUS.md` updated. An RFC is linked if required.
- [ ] Hello World Gallery still passes, with no growth in line counts.
- [ ] Output is deterministic and reproducible.

## Style

- Envo: one canonical format (`envo fmt`, from M5). `PascalCase` for types, methods and
  properties; `camelCase` for locals and parameters; `snake_case` for module paths;
  `SCREAMING_CASE` only for true constants.
- `.eas`: see [`docs/spec/eas.md`](docs/spec/eas.md#style). Every routine starts with a
  header comment giving its inputs, outputs and clobbered registers.
- Line endings are LF everywhere (enforced by `.gitattributes`).

## Conduct

Everyone here follows the [Code of Conduct](CODE_OF_CONDUCT.md).
