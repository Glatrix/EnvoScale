# `runtime/vm` — the script runtime

> **Status:** Experimental (M6): an interpreter for EIR, behind `envo run`, scripts
> (`envo file.envo`, `#!/usr/bin/env envo`) and the REPL. Compiled into `envo`.

`envo run` compiles the program for this machine in memory, runtime included, and hands
the EIR module to the VM (PLAN D31, D32):

- **Host memory.** A pointer is a host address; a slot is a piece of the VM's own slot
  stack; a global is a host allocation filled from its initializer. Layouts, wrapping,
  checks and conversions are the native program's, so both modes print the same thing.
- **Its own call stack.** Calls push a frame on the VM's frame stack instead of
  recursing on the host's, so a script can recurse as deep as a native program.
- **The runtime is interpreted too.** A failed check calls the interpreted `__rt_trap`,
  so a panic prints exactly what it prints natively. The VM starts a program through
  `__rt_init`, sets its arguments with `__rt_set_args` (the script's, not `envo`'s),
  calls `__main` and ends through `__rt_exit`.
- **System calls are forwarded.** The runtime's two target intrinsics (`syscall` on
  Linux, `wincall` on Windows) go to the host through `platform.RawCall`, past the
  permission checks in [`sandbox.envo`](sandbox.envo).
- **Function values** are tagged function indexes, not code addresses.

Floating-point instructions are not run yet (Envo-S1 has no floats). Instructions are
decoded once into the VM's own form (operands as frame indexes or constants), and the
most frequent operations are tested first. Speed: 35 to 100 times slower than `-O0`
native code ([`tests/bench`](../../tests/bench/README.md)); a JIT that reuses the
native backends comes later.

Files: `vm.envo` (the interpreter), `sandbox.envo` (permissions). Tests: every spec run
program and every library test run in both modes (`bootstrap.* test`, `envo test`);
`tests/sandbox`.
