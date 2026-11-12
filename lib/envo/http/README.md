# `envo.http`

> **Status:** Experimental (M7): HTTP/1.1 messages, a client and a server over the Net
> port (PLAN D42). Tests: `lib/envo/http/tests/`. `https://` goes through `envo.tls`;
> HTTP/2 and HTTP/3 later.

## Simple door

```envo
use envo.http;

http.Response Hello(in http.Request req) => http.Response.Text(200, "Hello, World!");

http.Router app = http.Router.New();
app.Get("/", new http.Handler { Fn = Hello });
http.Serve(ref app, "127.0.0.1", 8080);
```

The brief's `serve(8080) { get("/") => "Hello, World!" }` needs trailing blocks, which
Envo-S1 does not have; it becomes this door's sugar when the language does. Handlers are
wrapped in a `Handler` because Envo-S1 stores a function value only from a field
initializer (RFC 0003).

```envo
var r = http.Get("http://127.0.0.1:8080/").Unwrap();
print(r.BodyText());
```

## Full-control door

- `Request`, `Response`, `Header`; `Response.Text`, `Response.Html`; `HeaderValue`
  (any case) and `SetHeader`.
- `WriteRequest`, `WriteResponse`, `ParseRequest`, `ParseResponse`: the wire format,
  with bodies by `Content-Length`, chunked transfer coding (read) or until close.
- `SendWith(ref net, url, request)` and `ServeOneWith(ref net, ref router, listener)`
  take any `INet`: the in-memory `os.none.Net` in a test. `SendTrusting` takes the trust
  anchors for `https://`.
- `Router`: exact paths by method; 404 for an unknown path, 405 for a known path and
  another method; HEAD answers as GET without the body. Requests over 1 MiB get 413.

One request per connection (`Connection: close`), one connection at a time.

## Ports used

Net (`ports.INet`).
