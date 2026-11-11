# `envo.web`

> **Status:** Not started. Planned for **M9**. Tier when it lands: Experimental.

Websites and web apps: HTTP server, router, forms, sessions, auth helpers, asset pipelines, SSG/SSR/client rendering, and Lumen templates.

## Simple door

```envo
site("Hello") { page("/") => Landing(title: "Hello, World!") }
```

## Full-control door

Per-page rendering strategy, custom components, raw `envo.http` access.

## Ports used

NetStack, FileSystem, Executor
