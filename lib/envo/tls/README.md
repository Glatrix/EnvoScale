# `envo.tls`

> **Status:** Experimental, **not audited** (M7): a TLS 1.3 client (RFC 8446; PLAN D41).
> Tests: [`tests/tls`](../../../tests/tls/README.md), against `openssl s_server`.

- Key exchange X25519; cipher suites `TLS_CHACHA20_POLY1305_SHA256` and
  `TLS_AES_128_GCM_SHA256` (from `envo.crypto`).
- The server is verified before any application data: its certificate chain to the
  trust anchors given (`envo.crypto.x509`), its name against the host asked for, its
  CertificateVerify signature (ECDSA P-256/P-384, RSA-PSS) and its Finished MAC. A
  connection that cannot be verified fails; there is no switch to skip verification.
- Trust anchors: `SystemRoots()` reads the PEM file named by `SSL_CERT_FILE`, else the
  platform's (`ports.ITrust`: the Windows ROOT and AuthRoot stores; the Linux CA
  bundle). Windows adds some roots to its stores only when its own APIs first need
  them, so a site whose root this machine has never used may fail until it has; set
  `SSL_CERT_FILE` to a CA bundle to avoid that.

Not yet: HelloRetryRequest, client certificates, resumption and 0-RTT, KeyUpdate, the
server side, `TLS_AES_256_GCM_SHA384`.

## Simple door

```envo
use envo.http;
var r = http.Get("https://github.com/").Unwrap();     // https:// goes through envo.tls
```

## Full-control door

```envo
var net = platform.Net();
var conn = tls.ConnectWith(ref net, "localhost", 8443, tls.RootsFromPem(pem), "").Unwrap();
tls.Send(ref net, ref conn, request);
usize n = tls.Recv(ref net, ref conn, buffer).Unwrap();
tls.Close(ref net, ref conn);
```

## Ports used

Net, Trust, Entropy (keys), Clock (certificate validity), Environment and FileSystem
(`SSL_CERT_FILE`).
