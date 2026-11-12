# `tools/fuzz`

> **Status:** M13. The fuzzer is `envo fuzz` (`tools/envo/fuzz.envo`), in the `envo` binary.

Coverage-guided fuzzing in the script runtime (PLAN D64):

```
envo fuzz target.envo [--runs N] [--seed N] [--max-len N] [--corpus DIR] [-O2] [--allow …]
```

- **Targets** are programs that read the file named by their first argument. A panic is
  a crash; any other ending is fine. `envo run target.envo <file>` replays an input.
- The target is compiled once. Every input runs in the same VM: exits and panics end the
  run, not the process, the globals are reset, and the input file is served from memory
  (no disk per run).
- **Coverage:** the VM notes each EIR block that runs. An input that runs a block no
  earlier one did joins the corpus (`build/fuzz/<target>/corpus`, or `--corpus`).
- **Mutations:** bit flips, random and interesting bytes, insertions, deletions, copies,
  splices, small additions, and a **dictionary** of the constants the target's own code
  compares with (found in its EIR), written over or inserted.
- **Deterministic:** the same seed, target and corpus give the same session on the same
  host (coverage of the OS adapter differs between hosts).
- A crash is saved as `build/fuzz/<target>/crash` and replayed once with its output.

`tests/envo/fuzz/magic.envo` panics only for input starting `FUZ!`, checked a byte at a
time; the fuzzer finds it in a few hundred to a few thousand runs. Fuzz targets for the
parser, the EIR verifier, the format decoders, TLS and HTTP, run in CI, come next.
