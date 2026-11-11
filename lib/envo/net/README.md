# `envo.net`

> **Status:** Not started. Planned for **M7**. Tier when it lands: Experimental.

TCP, UDP and DNS; later QUIC. Client and server share the same types.

## Simple door

```envo
var conn = net.Connect("example.com:80")?;
```

## Full-control door

Socket options, custom resolvers, and the raw `NetStack` port.

## Ports used

NetStack, Executor
