# Bootstrap tests

> **Status:** Not started. Stage equivalence arrives with M2; the fixed-point check with M3; seed equivalence with M13.

Checks that keep the trust chain honest: Stage 0 built by NASM == built by the seed == built by `envo asm`; Stage 2 compiled by itself twice is byte-identical (fixed point).
