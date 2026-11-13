# crypto

A SHA-256 digest, and an Ed25519 signature that catches a changed message.

```cs
use envo.crypto;
use envo.crypto.curve25519;
use core.text as ct;

print(crypto.Sha256("Hello, World!").Hex().AsStr());

// A fixed key, so the output is the same every run; use crypto.RandomBytes for real keys.
u8[32] secret;
for (usize i = 0; i < 32; i++) secret[i] = i as u8;
u8[32] key;
curve25519.Ed25519Public(secret[0..32], key[0..32]);

str message = "pay 10 to alice";
u8[64] signature;
curve25519.Ed25519Sign(secret[0..32], ct.Bytes(message), signature[0..64]);

if (curve25519.Ed25519Verify(key[0..32], ct.Bytes(message), signature[0..64])) print("signature ok");
if (!curve25519.Ed25519Verify(key[0..32], ct.Bytes("pay 99 to alice"), signature[0..64])) print("changed message rejected");
```

```
$ envo run .
dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f
signature ok
changed message rejected
```
