# `tests/sandbox` — script permissions

> **Status:** M6. Run by `build.ps1 test` / `build.sh test`.

Each program runs in the script runtime (`envo run`) in a scratch copy of this folder,
with one `--allow` per `// allow:` line. Its standard output must be its `// expect:`
lines, its exit code 0, and its standard error must contain each `// expect-stderr:`
text (the notes `envo` prints when it denies something).

| Program | Permissions | Checks |
|---|---|---|
| `nothing.envo` | none | the console works; reading, writing, listing, making folders, environment variables and starting programs are denied |
| `read_only.envo` | `read` | reading and listing work; writing and deleting are denied |
| `paths.envo` | `fs:box` | reading and writing under `box/` work; outside it, and `box/../`, are denied |
| `env_only.envo` | `env,read:env_only.envo` | a comma list; one named file |
| `everything.envo` | `all` | everything works |

The bootstrap script for Linux also runs a `#!/usr/bin/env envo` script found on `PATH`.
