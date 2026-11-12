# `tests/tls` — the TLS 1.3 client against a real server

> **Status:** M7. Run by `bootstrap.ps1 test` / `bootstrap.sh test` when `openssl` is
> installed (it is on the CI runners); skipped, with a note, when it is not.

The scripts make a throwaway CA (P-256) and two server certificates it signs (RSA-2048
and P-256, for `localhost`), start `openssl s_server -tls1_3 -www` on a local port, and
run `client.envo` (built by Stage 2), which trusts only that CA:

| Server | Cipher suite | Expected |
|---|---|---|
| RSA certificate | `TLS_AES_128_GCM_SHA256` | `HTTP/1.0 200 ok` |
| P-256 certificate | `TLS_CHACHA20_POLY1305_SHA256` | `HTTP/1.0 200 ok` |
| a certificate from another CA | any | `failed: the server's certificate is not trusted: …` |

This covers the handshake, both cipher suites, chain verification, RSA-PSS and ECDSA
CertificateVerify signatures, both Finished messages and application data.
