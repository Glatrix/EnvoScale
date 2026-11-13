<p align="center"><img src="docs/images/wordmark.svg" alt="EnvoScale" width="380"></p>

<img src="docs/images/experimental.svg" alt="Experimental: this project is an experiment, built with heavy use of AI. While it is early, some functionality may not work as intended." width="100%">

# Envol

A programming language that compiles to small native programs for Windows, Linux, macOS
and the browser, and comes with one tool, `envo`, that builds, runs, tests, formats and
packages it. The compiler, the standard library and the tool are written in Envol, with no
third-party code.

```cs
enum Shape {
    Circle(i64 radius),
    Rect(i64 width, i64 height),
}

i64 Area(in Shape s) => match s {
    Circle(r) => 3 * r * r,
    Rect(w, h) => w * h,
};

List<Shape> shapes = List<Shape>.New();
shapes.Push(Shape.Circle(2));
shapes.Push(Shape.Rect(3, 4));

i64 total = 0;
foreach (var s in shapes.AsSlice()) total += Area(s);
```

## Install

Download a [release](https://github.com/envoscale/EnvoScale/releases), unpack it, and run
`bin/envo run hello.envol`. Or build from source, with nothing but a shell:

```bash
git clone https://github.com/envoscale/EnvoScale
cd EnvoScale
./build.sh build                      # .\build.ps1 build on Windows without Git Bash
build/envo/envo run examples/00-hello/main.envol
```

## Learn

| | |
|---|---|
| [`examples/`](examples) | Small programs, one idea each |
| [`docs/spec/`](docs/spec) | The language specification |
| [`docs/`](docs) | How the compiler, the library and the tools are built |

## The `envo` tool

`envo run` (sandboxed scripts), `envo build` (native executables, any target from any host),
`envo new`, `envo test`, `envo fmt`, `envo lsp` (any editor; [VS Code](adapters/editors/vscode)),
`envo dbg`, `envo prof`, `envo fuzz`, `envo repl`, `envo explain`. Packages depend on each
other by path, registry or git commit.

## The ecosystem

| | |
|---|---|
| [Envor](https://github.com/envoscale/Envor) | Rendering: 2D, fonts, 3D, themes |
| [Envoui](https://github.com/envoscale/Envoui) | The UI framework |
| [EnvoScaleWeb](https://github.com/envoscale/EnvoScaleWeb) | Websites, and this project's site |
| [EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm) | The compiler, built from a few kilobytes of readable assembly |

## This repository

| | |
|---|---|
| [`compiler/`](compiler) | `envoc`, the compiler |
| [`lib/`](lib) | The standard library: `core`, `alloc`, `std`, and `envo.*` (crypto, TLS, HTTP, JSON, AI) |
| [`adapters/`](adapters) | Everything that talks to an operating system or a driver |
| [`tools/`](tools) | `envo` |
| [`runtime/`](runtime) | The interpreter behind `envo run` |
| [`tests/`](tests) | The test suites; `./build.sh test` runs them all |

The compiler compiles itself; the first compiler comes from
[EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm), which builds it from assembly.

## License

Free for noncommercial use under the PolyForm Noncommercial License 1.0.0; companies need a
commercial license ([licensing](docs/legal/licensing.md)).
