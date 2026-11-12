# EnvoScale

**One environment, every platform, built from the first byte up.**

EnvoScale is one language (**Envo**), one toolchain (`envo`) and one standard platform
(`envo.*`) for systems code, scripts, desktop apps, websites, terminals, graphics, AI,
crypto and networking. It has no third-party dependencies, and its compiler is
bootstrapped from assembly so the whole chain can be audited.

> **Status: early, and Experimental throughout.** M0–M8 are done. `envoc0` (assembly)
> and `envoc1` (Envo) bootstrap `envoc`, the compiler that compiles itself, for Windows,
> Linux and now WebAssembly. On top of it:
> - the `envo` tool, with a sandboxed script runtime;
> - crypto, TLS and HTTP;
> - terminal and desktop UI, fonts, 2D and GPU (Direct3D 12) drawing.
>
> M9, the web, is under way: this repository's website is an Envo program
> ([`website/`](website/README.md)). See [`STATUS.md`](STATUS.md) for details.

## Goals

- Hello World for any domain in one to three lines.
- Every layer open to experts, down to inline assembly and custom backends.
- Everything EnvoScale needs, it builds itself.
- A new OS, CPU or GPU API is an adapter, not a rewrite.

The rules the project holds itself to are in [`CHARTER.md`](CHARTER.md).

## Quick start

You need [NASM](https://www.nasm.us/) ([setup](adapters/bootstrap/nasm/README.md)) and
nothing else.

Windows (PowerShell):

```powershell
.\bootstrap.ps1 build      # builds all three compilers into build\
.\bootstrap.ps1 test       # runs the test suites
build\stage0\envoc0.exe lex examples\00-hello\main.envo
```

Linux:

```sh
./bootstrap.sh build
./bootstrap.sh test
build/stage0/envoc0 lex examples/00-hello/main.envo
```

`lex` prints the tokens:

```text
1:1 n ident print
1:6 j punct (
1:7 j string "Hello, World!"
1:22 j punct )
2:1 n eof
```

## Hello World Gallery

These live in [`tests/spec/hello/`](tests/spec/hello/), and CI fails if one gets longer
than its limit. Each becomes runnable at the milestone shown ([`docs/PLAN.md`](docs/PLAN.md)).

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

`/` separates lines.

## Repository map

| Path | Contents |
|---|---|
| [`bootstrap/`](bootstrap/README.md) | Seed, Stage 0 (assembly) and Stage 1 (Envo-Core) |
| [`compiler/`](compiler/README.md) | Stage 2 `envoc`, the real compiler |
| [`runtime/`](runtime/README.md) | Startup, panics, ARC, the EIR VM and JIT |
| [`lib/`](lib/README.md) | The standard platform: pure code and port interfaces |
| [`adapters/`](adapters/README.md) | All platform-specific code, and editor support (the VS Code extension) |
| [`tools/`](tools/README.md) | `envo` CLI, LSP, formatter, debugger |
| [`templates/`](templates/README.md) | Project and site templates |
| [`examples/`](examples/README.md) | Small runnable programs |
| [`tests/`](tests/README.md) | Spec, golden, conformance, bootstrap and fuzz tests |
| [`docs/`](docs/README.md) | Language spec, architecture notes, RFCs |

## Contributing

Start with [`CONTRIBUTING.md`](CONTRIBUTING.md). Language and API changes go through
[RFCs](docs/rfcs/README.md). Report security issues as described in [`SECURITY.md`](SECURITY.md).

## License

Free for individuals and noncommercial use under the PolyForm Noncommercial License 1.0.0.
Companies need a commercial license. [`LICENSING.md`](LICENSING.md) explains who needs
which, [`LICENSE`](LICENSE) has the terms, [`docs/legal/`](docs/legal/) has the commercial
templates, and [`TRADEMARKS.md`](TRADEMARKS.md) covers the name and logos.
