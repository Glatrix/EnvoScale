# `adapters/os/linux`

> **Status:** Experimental (M4, M5, M14): Console, FileSystem, Clock, Entropy,
> Environment, Process, Net, Trust, Terminal, Window (X11, M14.7). Passes every
> conformance suite (in CI, windows under Xvfb). Clipboard: none yet.

Linux adapters over raw x86-64 system calls through the `__syscall` intrinsic:
`newfstatat`, `unlink`, `mkdir`, `rmdir`, `getdents64`, `fork`, `execve`, `wait4`, `dup2`,
`clock_gettime`, `getrandom`, with the
runtime's `open`, `read` and `write`. Threads and an io_uring/epoll executor come with M6.

## Windows: `x11/`

`os.linux.x11` is an X11 client over the server's Unix socket, without Xlib: setup with
the Xauthority cookie, `CreateWindow`, `WM_PROTOCOLS`/`WM_DELETE_WINDOW`, `PutImage` in
strips under the request size limit, and events through the keyboard map
(`GetKeyboardMapping`). See [`docs/architecture/graphics.md`](../../../docs/architecture/graphics.md).
