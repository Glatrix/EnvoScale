# Official test vectors

> **Status:** M7, started. The vectors are copied into the library's test programs
> (`lib/envo/crypto/tests/`); this file records where each comes from (PLAN D38).

Every algorithm in `envo.crypto` exists only once the vectors from its standard pass,
natively and in the script runtime. The values are factual data from the standards
below; nothing else from those documents is copied.

| Algorithm | Source | Vectors | Test |
|---|---|---|---|
| SHA-256, SHA-512 | NIST FIPS 180-4 and its published examples | "abc", the empty message, the two-block message | `hashes.envo` |
| HMAC-SHA-256, HMAC-SHA-512 | RFC 4231 | test cases 1 and 2 | `hashes.envo` |
| HKDF-SHA-256 | RFC 5869 | appendix A.1 (test case 1) | `hashes.envo` |
| ChaCha20, Poly1305, ChaCha20-Poly1305 | RFC 8439 | sections 2.4.2, 2.5.2, 2.8.2 | `aead.envo` |
| AES-128, AES-256 | NIST FIPS 197 | appendix C.1 and C.3 | `aes.envo` |
| AES-GCM | The Galois/Counter Mode of Operation (McGrew, Viega), submitted to NIST | test cases 1 to 3 | `aes.envo` |
| X25519 | RFC 7748 | section 5.2 (tests 1, 2; one iteration), section 6.1 | `curve25519.envo`, `x25519_vm.envo` |
| Ed25519 | RFC 8032 | section 7.1, tests 1 to 3 | `curve25519.envo` |

Larger suites (Wycheproof, NIST CAVP) arrive as data files with a `SOURCE.md` each when
the library can read them in its tests.
