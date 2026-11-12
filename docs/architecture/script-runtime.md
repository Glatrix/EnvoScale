# The script runtime (M6)

> **Status:** M6, done. Decisions D31–D36 in [`PLAN.md`](../PLAN.md).

Envo has two execution modes with one meaning (brief §3.7): `envo build` makes native
code; `envo run`, `envo file.envo` and `#!/usr/bin/env envo` run the program in the
script runtime, sandboxed.

## One program, two engines (D31, D32)

The script runtime does not reimplement the language: it runs what the compiler makes.
`envo run` compiles the program for this machine in memory, runtime included, and
interprets the EIR module ([`runtime/vm`](../../runtime/vm/README.md)) on host memory.
Everything below the EIR (layouts, checks, panics, the runtime's own code) is the same
in both modes, so they agree by construction. The tests check it anyway: every spec run
program and every library test runs in both modes with the same output and exit code
(D35).

The VM forwards the runtime's system calls (`syscall`, `wincall`) to the host, so a
script reaches files, the console and other programs exactly as a native program does,
through the same adapters.

## Permissions (D34)

A script starts with its console and nothing else. `--allow` grants more:

| Permission | Grants |
|---|---|
| `read`, `read:<path>` | reading files and listing folders (under `path`) |
| `write`, `write:<path>` | creating, changing and deleting files and folders (under `path`) |
| `fs`, `fs:<path>` | both |
| `env` | environment variables |
| `run` | starting other programs |
| `net` | the network (M7) |
| `all` (or `-A`) | everything a native program may do |

Several can be given, as separate `--allow` flags or a comma list. Paths are made
absolute against the working directory and resolved (`..` cannot climb out); on Windows
they compare without case. Looking at a path's metadata (does it exist, is it a folder)
needs read or write permission on it, or `run` (programs are found that way).

The VM checks each forwarded call: on Linux `open`/`openat` (read or write by the
flags; `/proc/self/environ` counts as `env`), `creat`, `unlink`, `mkdir`, `rmdir`,
`newfstatat`, `execve`; on Windows `CreateFileW` (by the access and disposition),
`DeleteFileW`, `CreateDirectoryW`, `RemoveDirectoryW`, `GetFileAttributesW`,
`FindFirstFileW`, `CreateProcessW`, `GetEnvironmentVariableW`, and the network calls
(`net`). The console and terminal calls are always allowed. The loader calls
(`GetModuleHandleW`, `GetProcAddress`, `LoadLibraryW`) and the window calls (USER32,
GDI32) need `all`, since each can run code the sandbox does not see. So does any call
through a function pointer (`wincallp`: GPU drivers, COM); without it the call returns 0,
and the GPU adapter falls back to drawing in software. A denied call fails as
the system fails a call it may not make (`-EACCES`; the function's failure value with
`ERROR_ACCESS_DENIED` from `GetLastError`), so the adapters report `IoError.Denied` and
the program decides what to do. The first denial of each kind prints a note:

```text
envo: permission denied: the script needs `--allow write` (or `--allow write:out.txt`)
```

Unsafe code can still reach memory it should not; the sandbox guards the outside world,
not the script's own memory.

## Scripts (D33)

`envo [--allow …] file.envo [args]` runs a script: permissions come before the file,
and everything after it is the script's. So an executable file starting with
`#!/usr/bin/env envo` (or `#!/usr/bin/env -S envo --allow read`) runs directly; the
lexer skips the `#!` line ([lex.shebang.1]).
