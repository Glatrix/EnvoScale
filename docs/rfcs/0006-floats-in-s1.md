# RFC 0006: Floats in Envo-S1

- **Status:** Implemented (M10 prerequisites, 2026-11-12). Accepted (2026-11-12). Under the owner's standing instruction to decide open
  design questions by the brief's core principles: one semantics for compiled code, the
  script runtime and `comptime` (brief §3.7, §4.1), and the full language's rules
  (chapters 1–3) wherever a subset can follow them.
- **Author(s):** founding engineer
- **Affects:** language (`docs/spec/envo-s1.md`), Stage 2's front end and both backends,
  the script runtime, `core.text`
- **Tracking:** PLAN §5 (M10 blocked; floats come first for M11 and M12)

## Summary

`f32` and `f64` join Envo-S1 in Stage 2. They come with float literals, arithmetic,
comparisons, `as` conversions, and formatting and parsing in `core.text`, all with the
full language's rules (chapter 2, [type.lit.2], [type.conv.1]; EIR §5.3, §5.4). Stage 1
stays without floats: like `tests/spec/s2-run`, float programs are Stage 2 programs.

## Motivation

Envo-S1 has no floats (`[s1.type.3]`). Everything that has worked around that so far has
done so in integers:
- `envo.gfx` and `envo.font` rasterize in fixed point;
- the GPU adapter builds IEEE bit patterns by hand for Direct3D;
- Lumen's tokens are whole pixels.

The next milestones cannot work around it. A PBR renderer (M11) and tensors with
autograd (M12) are float code from end to end, and EIR has had float types and
instructions since version 1.

## Guide-level explanation

```envo
f64 r = 2.5;
f64 area = 3.141592653589793 * r * r;
print(text.Float(area, 3).AsStr());     // 19.635 (alloc.text)

f32 half = 0.5f32;
i32 n = (area / 2.0) as i32;            // 9: toward zero
f64 big = 1e300 * 1e10;                 // inf, no panic
```

A literal with a fraction or an exponent is a float; it is `f64` unless a suffix
(`f32`) or the context says `f32`. Float arithmetic never panics: overflow gives
infinity, and `0.0 / 0.0` gives NaN, as IEEE 754 says. Converting a float to an integer
rounds toward zero and saturates, with NaN becoming 0, so it never panics either.

## Reference-level explanation

- **Types and literals.** `f32` and `f64`, with `float` and `double` as aliases
  ([type.prim]). Literals follow [lex.float.1]–[lex.float.3] and [type.lit.2]: an
  unsuffixed float literal takes the expected type if that is `f32` or `f64`, else `f64`.
  An integer literal is never implicitly a float (`f64 x = 1;` is E0301; write `1.0`).
- **Operators.** `+ - * /` and unary `-` (EIR `fadd`, `fsub`, `fmul`, `fdiv`, `fneg`);
  `== != < <= > >=` (`cmp.*` on floats, false on NaN except `!=`). There is no `%`, bit
  operator or shift on floats (E0302). Compound assignment follows the operators.
- **Conversions** (`as`): between `f32` and `f64` (`fext`, `ftrunc`); from any integer
  (`itof`, round to nearest even); to any integer (`ftoi`: toward zero, saturating, NaN
  to 0, [type.conv.1]). No implicit conversions.
- **Semantics.** Round to nearest even. Every NaN a computation produces is the target's
  default quiet NaN, so results are identical in native code, WebAssembly and the script
  runtime (EIR §5.3).
- **Backends.** x86-64 uses SSE2 scalar instructions. A float's bits live where an
  integer's do (frame slots and general registers) and pass through `xmm0`/`xmm1` for each
  operation; that is simple, and enough until a float register allocator pays for itself.
  WebAssembly reinterprets the `i64` locals as `f64`/`f32`. The script runtime does the
  same arithmetic with Envol's own floats.
- **Library.**
  - `alloc.text`: `Float(v, digits)` writes `v` with that many digits after the point,
    and `FloatShort(v)` with up to 15 significant digits and no trailing zeros.
  - `core.text`: `ParseFloat` reads decimal text. It is exact when the digits fit in 2^53
    and the exponent is within ±22, and within a few units in the last place otherwise.
  - `core.math`:
    - `Sqrt`, correctly rounded: Newton's method, then the exact residual by Dekker's
      product;
    - `Floor`, `Ceil`, `Round`, `Trunc`, `FAbs`, `FMin`, `FMax`, `FClamp`;
    - `Exp`, `Ln`, `Log2F`, `Log10`, `PowF`;
    - `Sin`, `Cos`, `Tan`, `Atan`, `Atan2`, `Asin`, `Acos`;
    - `PI`, `TAU`, `E`, `Bits` and `FromBits`, `IsNaN`, `IsFinite`.

    These are written from their definitions (range reduction and Taylor series with exact
    `1/n!` coefficients) and are within a few units in the last place.
- **Tests.** `tests/spec/s2-run`: literals, arithmetic, NaN and infinity, comparisons,
  conversions in every direction, and `f32` rounding. The same programs run natively at
  -O0 and -O2, in WebAssembly, and in the script runtime.

## Drawbacks

Floats bring NaN's comparison rules and rounding into a language whose integers are exact
and checked. They are opt-in by type, and the rules are the hardware's.

## Alternatives

- **Fixed point everywhere.** It works for 2D rasterization, as `envo.gfx` shows. It does
  not work for physically based shading or gradient descent, whose ranges no single
  scale fits.
- **Floats in Stage 1 too.** Stage 1 is the bootstrap compiler and needs none. Keeping it
  smaller keeps the audit chain shorter.

## Prior art

C#, Rust and Java give IEEE 754 binary32 and binary64 with round-to-nearest-even. Rust
and Java (since 2021) define saturating float-to-integer casts, as Envol does.

## Unresolved questions

- Fused multiply-add and other math functions beyond `Sqrt` (in M11 and M12, as their
  code needs them).
- Formatting with the shortest digits that round-trip.
