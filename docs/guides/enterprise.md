# EnvoScale in organizations

Facts for the people who deploy, administer and approve EnvoScale. Support terms, release
channels and response times are set by the commercial agreement; this page states only
what the software does today.

## Supported platforms

| Platform | Compiler and tools | Programs it builds | Notes |
|---|---|---|---|
| Windows 10/11, x86-64 | yes | yes | CI on every change |
| Linux, x86-64 | yes | yes | CI on every change |
| Web browsers (WebAssembly) | the compiler runs in the page | yes (`--target wasm32-web`) | the website's sandbox |
| macOS, AArch64 Linux | no | no | milestone M10, waiting on test machines |

Programs are static executables with no runtime to install: on Linux they need only the
kernel; on Windows, only system DLLs.

## Installation at scale

- One archive per release, the same bytes from any build host, with its SHA-256 and an
  Ed25519 signature: [offline installation](offline-install.md).
- No installer, no registry keys, no services: unpack anywhere, set `ENVO_HOME` (or keep
  the layout) and put `bin/` on `PATH`. Several versions can sit side by side.
- The whole toolchain can be rebuilt from source and checked against a release: the
  bootstrap scripts build Stage 0 from the hex seed without an assembler
  (`bootstrap/seed`), then each stage builds the next, and Stage 2 reproduces itself
  byte for byte.

## Data handling

- **No telemetry.** Neither the tools nor the programs they build send anything anywhere.
  The only network access the tools make is what you ask for: `envo fetch` and
  `envo publish` to the registries your manifests name.
- **No license checks** at run time or build time.
- **Scripts are sandboxed**: `envo run` gives a script its console and nothing else
  unless `--allow` grants files, the environment, processes or the network
  (`docs/architecture/script-runtime.md`).
- **The website sandbox** compiles and runs programs in the browser; nothing typed there
  leaves the machine (share links keep the program in the URL fragment, which browsers do
  not send to servers).

## Security properties of built programs

- Checked arithmetic, bounds and slice checks, and ownership rules make memory errors
  panics rather than corruption in safe code.
- Executables keep code and data on separate pages (W^X) and load at a random address
  (ASLR) on both Windows and Linux (PLAN D68).
- Parsers of untrusted input (HTTP, JSON, Markdown, GGUF, the tokenizer, EON) are fuzzed
  in CI (`tests/fuzz`).
- `envo.crypto` has not had an independent audit yet; see [SECURITY.md](../../.github/SECURITY.md).

## Licensing compliance

- EnvoScale has no third-party code. Its license is
  `PolyForm-Noncommercial-1.0.0 OR LicenseRef-EnvoScale-Commercial` (`LICENSING.md`).
- `envo build --sbom` writes an SPDX 2.3 bill of materials beside each program: the
  EnvoScale modules compiled in, with their license, and every dependency package with
  its version and SHA-256.
- Package archives are checked against `envo.lock.envon` and, when the manifest lists
  trusted keys, against Ed25519 signatures.

## Accessibility

Lumen, the design language of `envo.ui` and the website, meets WCAG 2.2 AA contrast in
its light and dark schemes: 4.5:1 for every text color on every surface, 3:1 for control
edges. `lib/envo/lumen/tests/contrast.envol` checks every pair on every change. Focus is
always visible (a focus ring in the accent color).
