# `envo.http`

> **Status:** Not started. Planned for **M7**. Tier when it lands: Experimental.

HTTP/1.1 client and server (HTTP/2 and HTTP/3 later), WebSocket, TLS via `envo.crypto`.

## Simple door

```envo
serve(8080) { get("/") => "Hello, World!" }
```

## Full-control door

Explicit router, middleware, connection limits, custom TLS configuration.

## Ports used

NetStack, Executor, Clock
