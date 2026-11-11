# `envo.crypto`

> **Status:** Not started. Planned for **M7**. Tier when it lands: Experimental until audited.

Hashes, MACs/KDFs, AEADs, X25519/Ed25519, ECDSA/ECDH, RSA, ML-KEM/ML-DSA, a CSPRNG and TLS 1.3. **Stays Experimental until an independent audit.** Rules: standardized algorithms only, constant-time code paths, official test vectors for everything, secrets zeroed on drop.

## Simple door

```envo
print(crypto.sha256("hello").Hex())
```

## Full-control door

Incremental hashers, explicit nonces and keys, `Secret<T>`, and hardware-accelerated implementations selectable at runtime.

## Ports used

Entropy
