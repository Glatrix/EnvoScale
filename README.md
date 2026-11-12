# EnvoScale

**One environment, every platform, every skill level, built from the first byte up.**

EnvoScale ("Environment Scale") is an all-in-one computing environment: one language
(**Envo**), one toolchain (`envo`), and one standard platform (`envo.*`) for systems
programming, scripts, desktop apps, websites, terminals, graphics, AI, cryptography and
networking. It has no third-party dependencies, and its compiler is bootstrapped from
assembly so the whole chain can be audited.

> **Status: early.** Milestones **M0**–**M2** are done: `envoc0`, the compiler written in
> assembly, builds Envo-Core programs for Windows and Linux, and `envoc1`, written in
> Envo-Core, compiles Envo-S1 (generics, interfaces, closures, ownership, enums,
> collections) the same way. **M3**, the self-hosting compiler, is next. Only the console
> line of the gallery below runs today. [`STATUS.md`](STATUS.md) is the honest, current
> picture.

## Why

- **Easy for beginners:** "Hello World" for any domain fits in 1–3 lines.
- **Unlimited for experts:** every layer opens up, down to inline assembly, allocators,
  memory layout and custom backends.
- **Self-sufficient:** whatever EnvoScale needs, it builds itself.
- **Self-hosting:** the compiler starts in assembly and ends up compiling itself.
- **Future-proof:** a new OS, CPU or GPU API is an adapter, not a rewrite.

The binding principles are in [`CHARTER.md`](CHARTER.md).

## 60-second quick start (what works today)

You need [NASM](https://www.nasm.us/) for the Phase A bootstrap (see
[`adapters/bootstrap/nasm/`](adapters/bootstrap/nasm/README.md)). Nothing else.

Windows (PowerShell):

```powershell
.\bootstrap.ps1 build      # assembles build\stage0\envoc0.exe (and the Linux binary)
.\bootstrap.ps1 test       # runs the Stage 0 test suites
build\stage0\envoc0.exe lex examples\00-hello\main.envo
```

Linux:

```sh
./bootstrap.sh build
./bootstrap.sh test
build/stage0/envoc0 lex examples/00-hello/main.envo
```

`envoc0 lex` prints the token stream:

```text
1:1 n ident print
1:6 j punct (
1:7 j string "Hello, World!"
1:22 j punct )
2:1 n eof
```

## Hello World Gallery

These programs are the project's promise. They live in [`tests/spec/hello/`](tests/spec/hello/),
and CI fails if any of them grows past its line count. They become runnable as the
milestones in [`docs/PLAN.md`](docs/PLAN.md) land.

| Domain | Program | Runs from |
|---|---|---|
| Console | `print("Hello, World!")` | M1 |
| CLI tool | `[Command] void Greet(string name = "World") => print($"Hello, {name}!")` | M8 |
| Window | `use envo.ui;` / `window("Hello") { Text("Hello, World!") }` | M8 |
| Website | `use envo.web;` / `site("Hello") { page("/") => Landing(title: "Hello, World!") }` | M9 |
| HTTP API | `use envo.http;` / `serve(8080) { get("/") => "Hello, World!" }` | M7 |
| Terminal UI | `use envo.term;` / `tui { Text("Hello, World!").Bold() }` | M8 |
| 3D | `use envo.render3d;` / `scene { cube().Spin(); light.Sun(); }` | M11 |
| 2D | `use envo.gfx;` / `window("Hi") { canvas(c => c.Circle(100, 100, 50, Lumen.Accent)) }` | M8 |
| Crypto | `print(crypto.sha256("Hello, World!").Hex())` | M7 |
| AI | `use envo.ai;` / `print(ai.Load("tiny.gguf").Ask("Say hello"))` | M12 |
| Systems | `[NoAlloc] extern "C" int main() { unsafe { asm x86_64 { /* … */ } } return 0; }` | M3 |

(`/` separates lines.)

## Repository map

| Path | What lives there |
|---|---|
| [`bootstrap/`](bootstrap/README.md) | The trust chain: hex seed → Stage 0 (assembly) → Stage 1 (Envo-Core) |
| [`compiler/`](compiler/README.md) | Stage 2 `envoc`, the real compiler, written in Envo |
| [`runtime/`](runtime/README.md) | Program startup, panics, ARC, the EIR VM and JIT tiering |
| [`lib/`](lib/README.md) | The standard platform: pure code and port interfaces only |
| [`adapters/`](adapters/README.md) | The only place platform-specific code may live |
| [`tools/`](tools/README.md) | The `envo` CLI, LSP, formatter, debugger, … |
| [`templates/`](templates/README.md) | `envo new` project templates and Lumen site templates |
| [`examples/`](examples/README.md) | Small runnable programs, one per domain |
| [`tests/`](tests/README.md) | Spec, golden, conformance, bootstrap and fuzz tests |
| [`docs/`](docs/README.md) | Language spec, architecture notes, RFCs, guides |

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) first. Language and API changes go through
the [RFC process](docs/rfcs/README.md). Security issues: see [`SECURITY.md`](SECURITY.md).

## License

EnvoScale is **free for individuals and noncommercial use** under the PolyForm
Noncommercial License 1.0.0. **Companies need a commercial license.** See
[`LICENSING.md`](LICENSING.md) for who needs which license, and [`LICENSE`](LICENSE) for
the terms. Commercial terms are public as templates in [`docs/legal/`](docs/legal/), and
the name and logos are covered by [`TRADEMARKS.md`](TRADEMARKS.md).
