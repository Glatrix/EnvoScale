# `tools/pkg`

> **Status:** M13. Packages are handled by the `envo` binary (`tools/envo/package.envo`,
> `deps.envo`, `registry.envo`).

A package is a folder with an `envo.envon` manifest (PLAN D27). Its `dependencies` block
names other packages (PLAN D66), by path or from a registry:

```eon
dependencies {
    greet = { path = "../greet" }
    words = { version = "1.2.0", registry = "../registry" }
}
trust {
    keys = ["4d74f238…"]        // Ed25519 public keys; when present, archives must be signed
}
```

Dependencies' sources are compiled with the package's (each keeps its namespaces), for
`envo build`, `run`, `test`, `prof`, `fuzz` and `dbg`.

| Command | Does |
|---|---|
| `envo fetch [dir]` | resolves the dependencies (each package once, in name order), gets registry archives, checks them, unpacks them into `build/deps/<name>-<version>`, and writes `envo.lock.envon` with each archive's SHA-256 |
| `envo pack [dir]` | writes `build/<name>-<version>.envopkg` and prints its SHA-256 |
| `envo publish [dir] --registry <folder> [--key <file>]` | adds the archive (and its signature) to a folder registry; a published version is never replaced |
| `envo key <file>` | a new Ed25519 secret key in `file`; prints the public key for `trust` |

**Reproducible and checked.** An archive (`.envopkg`) is `envopkg 1`, then each file
(sorted by path) with its size: the same folder always packs to the same bytes. Builds
use the lock: a registry package missing from it, or whose archive's SHA-256 differs, is
an error. With `trust` keys, the archive's SHA-256 must be signed by one of them.
Unpacking refuses paths that leave the folder.

**Registries** are reached through the `IRegistry` port (`Archive`, `Signature`,
`Publish`). `RegistryFolder` is its adapter for a folder (`<name>/<version>.envopkg`,
`.sig`), local or shared. A network registry is another adapter of the same port; where
to run one is the owner's decision (STATUS).

Tested by both bootstrap scripts with `tests/envo/pkg`: a path dependency, a signed
publish (and a refused second one), fetch and the lock, an untrusted key, a changed
archive.
