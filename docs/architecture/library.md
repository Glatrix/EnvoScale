# The standard platform: layers, ports and adapters (M4)

`lib/` is the standard platform, written in Envo-S1 and compiled by `envoc` (Stage 2).
It reaches the outside world only through ports (`lib/ports`), which adapters
(`adapters/os/*`) implement. [`ports-and-adapters.md`](ports-and-adapters.md) gives the
general shape; this page records how M4 builds it. Decisions D21–D25 are in
[`PLAN.md`](../PLAN.md).

## Layers

| Module | Namespace | What it has | Ports |
|---|---|---|---|
| `lib/core/text` | `core.text` | search, trim, split once, ASCII classes | none |
| `lib/core/fmt` | `core.fmt` | integers to text and back, into a caller's buffer | none |
| `lib/core/math` | `core.math` | integer helpers | none |
| `lib/core/hash` | `core.hash` | FNV-1a, SplitMix mixing, the `IKey` interface for hash tables | none |
| `lib/alloc/map`, `set`, `box` | `alloc.map`, … | `Map<K, V>`, `Set<T>`, `Box<T>` | none |
| `lib/alloc/text` | `alloc.text` | text helpers that build a `string` or a `List<str>` | none |
| `lib/ports` | `ports` | `IConsole`, `IFileSystem`, `IClock`, `IEntropy`, `IEnvironment`, `IProcess`, `IoError` | defines them |
| `lib/std/io`, `fs`, `path`, `time`, `env`, `random`, `process` | `std.io`, … | the OS-level services | Console, FileSystem, Clock, Entropy, Environment, Process |

`core` allocates nothing. `alloc` adds the heap. The S1 prelude (`List`, `string`,
`Option`, `Result`) is still the one Stage 1 embeds; it moves into `lib/prelude` once
`envoc` compiles its own prelude.

## Finding a module (D21)

`envoc --lib <dir>` names the folder that holds `lib/` and `adapters/`. When a file says
`use a.b` and no loaded file declares namespace `a.b`, `envoc` loads
`<dir>/lib/a/b/b.envo`, then does the same for the files it loaded, until nothing new is
used. The rule maps a namespace to exactly one file, because the runtime cannot list a
folder yet. Package manifests (`envo.envon`, M5) will let a module span files.

`use a.b;` makes `b` a name for the namespace, in types too (`b.Map<K, V>`).

A used namespace that no file declares and that has no module file is **E0214**.

## Adapters and the platform binding (D22, D23)

A port is an interface, used through generic bounds: Envo-S1 has no dynamic interface
values (D13, D22). Each adapter is a struct that implements the port:

| Namespace | Folder | Adapters |
|---|---|---|
| `os.none` | `adapters/os/none` | reference: captured `Console`, pass-through `Terminal`, in-memory `FileSystem`, manual `Clock`, seeded `Entropy`, fixed `Environment`, scripted `Process` (echoing programs known by name) |
| `os.windows` | `adapters/os/windows` | KERNEL32 and ADVAPI32 through `__wincall` |
| `os.linux` | `adapters/os/linux` | system calls through `__syscall` |

`os.<name>` loads `adapters/os/<name>/<name>.envo`. The namespace **`platform`** is the
one place where `lib/` meets an adapter. It loads `adapters/os/<os>/platform.envo`, where
`<os>` is the target's operating system or `none` with `--os none`. Every binding
provides the same constructors: `platform.Console()`, `FileSystem()`, `Clock()`,
`Entropy()`, `Environment()`, `Process()`. Code that uses them writes `var fs = platform.FileSystem();`
and works with any binding.

Each `std` module has two doors. The simple door (`fs.ReadText(path)`) uses the platform
binding. The full-control door (`fs.CreateDirAllWith(ref myFs, path)`) takes any adapter,
such as an in-memory file system in a test.

A file under `lib/` may use `platform` but no `os.*` namespace (**E0215**). The library
names the binding, never an adapter, so it stays platform-free.

With `--os none` a program is deterministic and touches nothing outside itself:
- files are in memory;
- the clock stands at 2026-01-01 00:00 UTC;
- entropy is seeded with 0;
- the only argument is `program`.

Its console is still the process's own, so its output can be read.

## Native adapters (D25)

The native adapters call the OS directly through the target intrinsics:
- `__syscall(n, …)` on Linux;
- `__wincall(k, …)` on Windows, where `k` is a slot in the executable's import address
  table.

M4 grew the Windows import table, identically in Stage 1 and Stage 2, so their
executables stay byte-identical:
- KERNEL32 slots 0–18 (12–18 are new: the precise system time, the performance counter,
  `DeleteFileW`, `CreateDirectoryW`, `RemoveDirectoryW`, `GetFileAttributesW`);
- M5 (D28) added slots 19–26: `CreateProcessW`, `WaitForSingleObject`,
  `GetExitCodeProcess`, `FindFirstFileW`, `FindNextFileW`, `FindClose`,
  `SetHandleInformation`, `GetEnvironmentVariableW`;
- slot 27 ends KERNEL32's;
- slot 28 is ADVAPI32's `SystemFunction036` (RtlGenRandom), the system's random
  generator.

`__wincall` takes the slot and up to 10 arguments (`CreateProcessW` has 10).

Paths reach Windows as UTF-16 and Linux as NUL-terminated copies. Both refuse a path that
holds a NUL byte.

## Conformance (M4.4, M4.5)

`tests/conformance/<port>/` holds one program per port. Each gets its adapter from
`platform` and checks what the port promises: for example, `Write` without its directory
is `NotFound`, and the monotonic clock never goes back. It prints only failures and a
final line. The test scripts run every suite against the reference adapters
(`--os none`) and against the native ones, at `-O0` and `-O2`, on both hosts in CI. An
adapter is complete when its suites pass.

## Tests

- `lib/*/tests/`, `adapters/os/*/tests/`: programs with `// expect:` lines, built by
  `envoc --lib` at `-O0` and `-O2`; `// os: none` selects the reference adapters.
- `tests/conformance/`: as above.
- `tests/spec/lib/`: library resolution errors (E0214, E0215).

## What waits for later

- `std.thread`, `sync`, `async` and the `Threads`, `Executor` and `NetStack` ports: the
  runtime is single-threaded (D24; M6–M7).
- Directory listing: no port operation yet. It needs `getdents64` and `FindFirstFileW`;
  planned with the build system (M5), which needs it.
- Floats (`core.math`), a `write` that reports errors, an allocator interface for
  collections: with the Envo features `envoc` does not compile yet.
