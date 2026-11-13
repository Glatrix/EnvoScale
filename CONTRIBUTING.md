# Contributing

Thanks for helping. A few rules keep the project in good shape.

## Before you start

EnvoScale is dual-licensed (free for noncommercial use, paid for companies; see
[licensing](https://github.com/envoscale/EnvoScale/blob/main/legal/licensing.md)). Contributions are accepted under the
[Contributor License Agreement](https://github.com/envoscale/EnvoScale/blob/main/legal/cla.md): say in your first pull request that you
agree to it. Pull requests without that are not merged.

## Rules

1. **Write it yourself.** Read any code, paper or spec you like, then write your own. Never
   paste code from another project. Official test vectors are welcome, with their source.
2. **No third-party dependencies**, anywhere. Operating system and hardware interfaces are
   reached only from `adapters/` ([principles](https://github.com/envoscale/EnvoScale/blob/main/project/principles.md)).
3. **`lib/` never imports `adapters/`.** `./build.sh check` fails if it does.
4. **No pretend code.** Nothing that claims to succeed without doing the work. Unfinished
   work gets a `TODO(#issue): reason`.
5. **A feature without tests does not exist.**
6. **Comments say why, not what.** Bigger design decisions go in the [architecture docs](https://github.com/envoscale/EnvoScale/tree/main/architecture) or
   an [RFC](https://github.com/envoscale/EnvoScale/blob/main/rfcs/README.md); changes to the language, the IR, a port or a stable API
   need an RFC first.

## Making a change

```bash
./build.sh check
./build.sh test
```

(`.\build.ps1 check` and `.\build.ps1 test` on Windows without Git Bash.) `test` builds the
compiler, checks that it rebuilds itself into the same bytes, and runs every suite.

One logical change per commit, with a message that says what changed and why. Update
[the status page](https://github.com/envoscale/EnvoScale/blob/main/project/status.md) if a subsystem moved forward or back.

## Tests

| Kind | Where | How |
|---|---|---|
| Language | `tests/spec/` | `.envol` files with `// expect: <output>` or `// expect-error: E0042 @ line:col` |
| Compiler output | `tests/golden/` | an input file and its expected output side by side |
| Library | `lib/**/tests/` | EnvoL programs run by `envo test` |
| Ports | `tests/conformance/` | one suite per port, run against every adapter |
| Tools | `tests/envo/`, `tests/lsp/` | the `envo` commands and the language server |

## Style

`envo fmt` decides the layout. `PascalCase` for types, methods and properties, `camelCase`
for locals and parameters. Line endings are LF everywhere.

## Conduct

Everyone here follows the [Code of Conduct](.github/CODE_OF_CONDUCT.md). Report security
problems as described in [SECURITY.md](.github/SECURITY.md).
