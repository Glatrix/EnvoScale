# `core`

> **Status:** Experimental (M4). Written in Envo-S1. Tests: `lib/core/tests/`.

Works without an allocator or an OS. Modules (`use core.text;` and so on;
[`library.md`](../../docs/architecture/library.md)):

- `core.text`: `IndexOf`, `LastIndexOf`, `Contains`, `Count`, `StartsWith`, `EndsWith`,
  `Trim`, `SplitOnce`, `EqualsIgnoreCase`, `CharCount`, ASCII classes. Positions are byte
  offsets.
- `core.fmt`: `WriteI64`, `WriteU64`, `WriteHex` into a caller's buffer; `ParseI64`,
  `ParseU64`, `ParseHex` (null for anything but a whole, in-range number).
- `core.math`: `Min`, `Max`, `Clamp` (and `…U`), `Abs`, `Pow`, `DivCeil`,
  `IsPowerOfTwo`, `NextPowerOfTwo`, `Log2`, `Gcd`.
- `core.hash`: FNV-1a (`Str`, `Bytes`), `Mix`, `Combine`, and `IKey<T>`, the key
  interface of the hash tables, for the integer types, `bool`, `str` and `string`.

## Simple door

```envo
use core.text;
if (text.Contains(line, "TODO")) count++;
```

## Full-control door

Everything is usable with no allocator: `fmt.WriteI64(buf[0..24], v)` fills a buffer
the caller owns.

## Ports used

none

## Not yet

Floats and formatting with `$"…"` interpolation wait for `envoc` to compile them.
