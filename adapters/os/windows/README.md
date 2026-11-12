# `adapters/os/windows`

> **Status:** Experimental (M4): Console, FileSystem, Clock, Entropy, Environment. Passes
> every conformance suite.

Windows adapters over KERNEL32.dll and ADVAPI32.dll, called through the `__wincall`
intrinsic: `__wincall(k, …)` calls the import in slot `k` of the executable's address
table (the list is in `bootstrap/stage1/x64/image.envo`). Paths are converted to UTF-16
for the `…W` functions; time comes from `GetSystemTimePreciseAsFileTime` and the
performance counter, random bytes from `SystemFunction036` (RtlGenRandom). Threads and
an IOCP executor come with M6.
