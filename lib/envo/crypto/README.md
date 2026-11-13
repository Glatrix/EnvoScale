# `envo.crypto`

> **Status:** Experimental, **not audited** (M7, in progress). Do not use it to protect
> anything that matters until an independent audit is published in
> [`SECURITY.md`](../../../.github/SECURITY.md).

Cryptography in Envo-S1 (PLAN D37), one module per family:

| Module | Contents | Standard | State |
|---|---|---|---|
| `envo.crypto.sha2` | `Sha256`, `Sha384`, `Sha512` (incremental: `New`, `Update`, `UpdateText`, `Finish`) | FIPS 180-4 | vectors pass |
| `envo.crypto.mac` | `HmacSha256`, `HmacSha512`, `HkdfExtract256`, `HkdfExpand256`, `Equal` (constant time) | RFC 2104, 4231, 5869 | vectors pass |
| `envo.crypto.chacha` | `Block`, `Xor` (ChaCha20), `Poly1305`, `Seal` and `Open` (ChaCha20-Poly1305) | RFC 8439 | vectors pass |
| `envo.crypto.aes` | `Aes` (AES-128/256 block), `Gcm` (`Seal`, `Open`) | FIPS 197, SP 800-38D | vectors pass |
| `envo.crypto.curve25519` | `X25519`, `X25519Base`, `Ed25519Public`, `Ed25519Sign`, `Ed25519Verify` | RFC 7748, 8032 | vectors pass |
| `envo.crypto.bigint` | `Nat`, `Mont` (Montgomery arithmetic for public values: not constant time) | none | used by rsa and ecdsa |
| `envo.crypto.rsa` | `PublicKey`, `VerifyPkcs1` (SHA-256/384/512), `VerifyPkcs1Sha256`, `VerifyPssSha256` (verification only) | RFC 8017 | OpenSSL signatures pass |
| `envo.crypto.ecdsa` | `Curve.P256`, `Curve.P384`, `Verify`, `SplitDer` (verification only) | FIPS 186-5 | OpenSSL signatures pass |
| `envo.crypto.x509` | `Parse`, `FromPem`, `MatchesHost`, `VerifyChain`, `SignedBy` (RSA PKCS #1 v1.5 SHA-256/384/512 and PSS; ECDSA P-256/SHA-256, P-384/SHA-384) | RFC 5280, 6125 | an OpenSSL-made chain verifies |
| `envo.crypto.random` | `Rng` (`New`, `From`, `Fill`, `Below`): ChaCha20 keyed from the `Entropy` port, with fast key erasure (D39) | none | tested against the key stream |
| `envo.crypto` | the simple door: `Sha256`, `Sha512`, `HmacSha256` (a `Digest` with `Hex`, `Equals`), `RandomBytes`, `RandomHex` | none | tested |

Rules (brief §7.2): standardized algorithms only; constant-time code paths (no branch,
loop bound or memory index depends on a secret; tags compare in constant time); every
algorithm passes its official vectors (copied into the tests in each module's `tests/` folder, with their source named).

## Simple door

```envo
use envo.crypto;
print(crypto.Sha256("hello").Hex().AsStr());
string token = crypto.RandomHex(16);
```

## Full-control door

```envo
use envo.crypto.chacha;
chacha.Seal(key, nonce, aad, data, tag);        // encrypts data in place
bool ok = chacha.Open(key, nonce, aad, data, tag);
```

## Ports used

Entropy (the CSPRNG).

## Speed

Plain Envo-S1 with no tables or hardware instructions: AES computes its S-box, the
curve uses 16-bit limbs. Fine for keys, handshakes and tests; slow for bulk data. The
full X25519/Ed25519 vector set takes about two minutes in the script runtime, so it runs
natively only (`x25519_vm.envol` covers the curve there).
