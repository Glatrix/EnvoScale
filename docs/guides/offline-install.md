# Installing EnvoScale offline

EnvoScale installs from one archive and needs no network: no package downloads, no
license server, no telemetry. This guide covers checking a release, installing it on a
machine without network access, and mirroring releases and packages inside an
organization.

## What a release is

| File | What it is |
|---|---|
| `envoscale-<version>.tar` | the toolchain: `bin/` (`envo` and `envoc` for Linux and Windows), `lib/`, `adapters/`, `docs/`, the licenses |
| `envoscale-<version>.tar.sig` | the Ed25519 signature of the archive's SHA-256 |
| `envoscale-<version>.provenance.json` | how the archive was built (see [Provenance](#provenance)) |
| `SHA256SUMS` | the archive's SHA-256 |

The archive is reproducible: `build.sh dist` (or `build.ps1 dist`) on the same
source gives the same bytes on Linux and Windows, so anyone can rebuild a release and
compare. The seed compiler the build starts from can itself be rebuilt from a hex seed
and the OS alone ([EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm)), so the whole
chain can be rebuilt from source.

## 1. Check the archive

On a machine you trust, with the release's public key (published with the release):

```bash
sha256sum -c SHA256SUMS
envo verify envoscale-<version>.tar --key <public key hex>
```

On Windows, `Get-FileHash -Algorithm SHA256 envoscale-<version>.tar` gives the digest to
compare with `SHA256SUMS`. Without `envo` at hand, OpenSSL 3 checks the signature too:
the signed message is the archive's SHA-256 written as 64 lowercase hex digits.

## 2. Install it

Copy the three files to the machine by whatever means your policy allows, then:

```bash
tar -xf envoscale-<version>.tar -C /opt
export ENVO_HOME=/opt/envoscale-<version>
export PATH="$ENVO_HOME/bin:$PATH"
envo version
```

On Windows, `tar` ships with Windows 10 and later:

```powershell
tar -xf envoscale-<version>.tar -C C:\Tools
$env:ENVO_HOME = 'C:\Tools\envoscale-<version>'
$env:PATH = "$env:ENVO_HOME\bin;$env:PATH"
envo version
```

`envo` finds the library through `ENVO_HOME`, or above its own executable, so setting
`PATH` alone also works when the folder layout is kept.

## 3. Mirror releases

Keep the archive, its `.sig` and `SHA256SUMS` together on an internal file share or web
server. Clients check the signature against the public key you distribute with your
machine images, not against the mirror, so the mirror need not be trusted.

## 4. Packages without network

Package dependencies come from registries you choose (`tools/pkg/README.md`):

- **A folder registry** on a share: `registry = "<folder>"`, a path relative to the
  package or absolute (a mounted share, or a UNC path on Windows). Copy
  approved packages into it with `envo publish --registry <folder> --key <your key>`.
- **An internal web server** holding the same folder layout: `registry =
  "https://packages.internal/envo"`, with `ENVO_REGISTRY_TOKEN` for access control.
- **Vendored**: after `envo fetch`, `build/deps/` holds every package's sources and
  `envo.lock.envon` their SHA-256; commit both, or copy them with the project.

Every archive is checked against `envo.lock.envon` and, when the manifest has a `trust`
block, against your signing keys, wherever it came from.

## Provenance

`dist` also writes `envoscale-<version>.provenance.json`, an
[in-toto](https://in-toto.io) statement in the SLSA provenance v1 format: the archive's
SHA-256, the source commit, the command that built it, the build time it used
(`SOURCE_DATE_EPOCH`), the CI run that built it (or `local`), and the SHA-256 of each
compiler on the way (the seed and `envoc`). The release manager signs it
with `envo sign` like the archive. CI builds the archive on Linux and on Windows from the
same commit and fails if the two digests differ.

## 5. Bills of materials

`envo build --sbom` writes an SPDX 2.3 SBOM beside each program, listing the EnvoScale
modules compiled into it and every dependency with its SHA-256. Set `SOURCE_DATE_EPOCH`
for reproducible SBOMs.
