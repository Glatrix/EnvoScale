# `envo.random`

> **Status:** Not started. Planned for **M4**. Tier when it lands: Experimental.

Fast non-cryptographic PRNGs and distributions. (Cryptographic randomness is `envo.crypto`.)

## Simple door

```envo
print(random.Int(1, 6))
```

## Full-control door

Explicit generator types and seeds for reproducible runs.

## Ports used

Entropy (only for default seeding)
