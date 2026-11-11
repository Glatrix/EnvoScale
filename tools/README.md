# `tools/` — the `envo` toolchain

> **Status:** Not started. The CLI with `new`, `build`, `run`, `test` and `fmt` plus a
> basic LSP arrive with **M5**. Until then, `bootstrap.ps1` / `bootstrap.sh` are the
> only entry points.

Every tool is written in Envo and ships inside the single `envo` binary.

| Command | Purpose | Folder |
|---|---|---|
| `envo new <template> <name>` | Create a project from `templates/projects` | `envo/` |
| `envo run [file]` | Run a script or project, sandboxed (`--allow ...`) | `envo/` |
| `envo build` | Compile (`--target`, `--release`, `-O`, `--emit`) | `envo/` |
| `envo test` / `envo bench` | Tests and benchmarks | `envo/` |
| `envo fmt` / `envo lint` | One canonical format; lints with auto-fixes | `fmt/`, `lint/` |
| `envo doc` | API docs as a Lumen site | `doc/` |
| `envo repl` | Interactive shell on the script runtime | `envo/` |
| `envo pkg add/publish/audit` | Package manager | `pkg/` |
| `envo dbg` / `envo prof` | Debugger (DAP) and sampling profiler | `dbg/`, `prof/` |
| `envo fuzz` | Coverage-guided fuzzer | `fuzz/` |
| `envo asm` / `envo eir` | Low-level tools | `envo/` (uses `compiler/asm`, `compiler/eir`) |
| `envo audit unsafe` | List every `unsafe` block and FFI boundary | `envo/` |
| `envo port check <adapter>` | Run a port conformance suite against an adapter | `envo/` |
| `envo lsp` | Language server (own JSON-RPC) | `lsp/` |
| `envo explain E0042` | Explain an error code | `envo/` |

Error messages are a feature: plain-language problem, labelled source snippet,
suggested fix, and a stable error code.
