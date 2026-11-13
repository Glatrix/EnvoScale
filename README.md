<p align="center"><img src="https://raw.githubusercontent.com/envoscale/.github/main/profile/assets/wordmark.svg" alt="EnvoScale" width="380"></p>

<img src="https://raw.githubusercontent.com/envoscale/.github/main/profile/assets/experimental.svg" alt="Experimental: this project is an experiment, built with heavy use of AI. While it is early, some functionality may not work as intended." width="100%">

# EnvoL

A programming language that compiles to small native programs for Windows, Linux, macOS
and the browser. One tool, `envo`, builds, runs, tests, formats and packages it. The
compiler, the standard library and the tool are written in EnvoL, with no third-party code.

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

Download a [release](https://github.com/envoscale/EnvoLang/releases), or build from source
with only Git and a shell:

```bash
git clone https://github.com/envoscale/EnvoLang
cd EnvoLang
./build.sh build                  # or .\build.ps1 build in PowerShell
build/envo/envo examples/00-hello/main.envol
```

## Learn

The documentation for EnvoL and every project around it is in
[EnvoScale](https://github.com/envoscale/EnvoScale):
[getting started](https://github.com/envoscale/EnvoScale/blob/main/getting-started.md),
[a tour of the language](https://github.com/envoscale/EnvoScale/blob/main/envol/README.md),
and [the `envo` commands](https://github.com/envoscale/EnvoScale/blob/main/envopm/README.md).
Here: [`examples/`](examples) and the [specification](spec).

## This repository

| | |
|---|---|
| [`compiler/`](compiler) | `envoc`, the compiler |
| [`lib/`](lib) | The standard library: `core`, `alloc`, `std`, and `envo.*` (crypto, TLS, HTTP, JSON, AI) |
| [`tools/envo/`](tools/envo) | `envo` |
| [`runtime/`](runtime) | The VM behind `envo run` |
| [`adapters/`](adapters) | Everything that talks to an operating system, and the editor extension |
| [`spec/`](spec) | The specification, read by `envo explain` and shipped with every release |
| [`examples/`](examples) | Small programs, each run in CI against its output |
| [`tests/`](tests) | The test suites; `./build.sh test` runs them all |

The compiler compiles itself. The first compiler comes from
[EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm), which builds it from assembly.

## License

Apache-2.0: see [LICENSE](LICENSE) and [NOTICE](NOTICE). Free for any use, including
commercial. The names and the logo are covered by the
[trademark policy](https://github.com/envoscale/EnvoScale/blob/main/legal/trademarks.md).
