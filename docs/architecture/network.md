# Network (M7)

> **Status:** M7, in progress. Decisions D40–D42 in [`PLAN.md`](../PLAN.md).

## The Net port (D40)

`ports.INet`: TCP over IPv4 (`Connect`, `Listen`, `LocalPort`, `Accept`, `Send`,
`Recv`, `Close`) and name lookup (`Resolve`). Handles are opaque numbers. A refused
connection is `IoError.Refused`, a new error kind.

| Adapter | How |
|---|---|
| `os.none` | In memory: listening ports, connections as pairs of buffers, names added with `AddName`; only 127.0.0.1 is reachable. A single program plays both ends. |
| `os.windows` | Winsock: `WS2_32.dll` is the executable's third imported DLL, slots 31–45 (`WSAStartup`, `socket`, `connect`, `bind`, `listen`, `accept`, `send`, `recv`, `closesocket`, `getaddrinfo`, `freeaddrinfo`, `WSAGetLastError`, `setsockopt`, `shutdown`, `getsockname`), in both Stage 1 and Stage 2 (D25). |
| `os.linux` | System calls (`socket`, `connect`, `bind`, `listen`, `accept`, `sendto` with `MSG_NOSIGNAL`, `recvfrom`, `getsockname`, `setsockopt`); names from `/etc/hosts`, then an A query over UDP to the first `nameserver` in `/etc/resolv.conf` (RFC 1035), waiting up to 5 seconds. |

`tests/conformance/net` checks every adapter over loopback: name lookup, a connection
both ways, end of stream after a close, and a refused connection.

In the script runtime, creating a socket or looking up a name needs `--allow net`
([`script-runtime.md`](script-runtime.md)); `/etc/hosts` and `/etc/resolv.conf` come with
it.

IPv6, UDP for programs, timeouts and non-blocking sockets come later.

## HTTP (D42)

[`lib/envo/http`](../../lib/envo/http/README.md): HTTP/1.1 messages, a client
(`Get`, `SendWith`) and a server (`Router`, `Serve`, `ServeOneWith`), one request per
connection.

## TLS (D41)

Planned in M7.7: a TLS 1.3 client with certificate verification, under `https://`.
