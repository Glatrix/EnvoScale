# `adapters/os/linux`

> **Status:** Experimental (M4): Console, FileSystem, Clock, Entropy, Environment. Passes
> every conformance suite (in CI).

Linux adapters over raw x86-64 system calls through the `__syscall` intrinsic:
`newfstatat`, `unlink`, `mkdir`, `rmdir`, `clock_gettime`, `getrandom`, with the
runtime's `open`, `read` and `write`. Threads and an io_uring/epoll executor come with M6.
