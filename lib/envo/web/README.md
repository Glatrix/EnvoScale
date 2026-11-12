# `envo.web`

> **Status:** Experimental (M9.3, M9.5). Tests: `lib/envo/web/tests/`.

Websites (PLAN D50, D51), on `envo.http`. A page is a function from a request (and its
route's parameters) to a response. The same pages are rendered per request by the server
(SSR) or once per path into files (SSG, `Build`), so a site has one code path. Lumen
supplies the look through `envo.web.templates`.

## Simple door

```envo
use envo.web;
use envo.http;

http.Response Home(in http.Request req, in web.Params ps) => http.Response.Html(200, "<h1>Hello, World!</h1>");

web.App app = web.App.New();
app.Get("/", new web.Page { Fn = Home });
web.Serve(ref app, "127.0.0.1", 8080);
```

## Full-control door

- `Html`: `Open`, `Attr`, `Text`, `Raw`, `Close`, `Element`, `Link`, `Done`. Text and
  attribute values are escaped; `Raw` is for HTML already made. `Escape(text)`.
- `App`: `Get`, `Post`, `Add(method, pattern, page)` with patterns like `/docs/:page` and
  `/files/*rest` (`Params.Get(name)`). `Static(prefix, folder)` serves a folder's files with
  their media types, and a folder's `index.html`. Paths with `..`, backslashes, colons or
  NUL bytes are refused. `Handle` and `HandleWith(ref fileSystem, request)`.
- `Serve`, `ServeOneWith(ref net, ref files, ref app, listener)`.
- `Build(ref files, app, paths, folder)` writes each path's page (`/` becomes
  `index.html`) and copies the static folders.
- `envo.web.templates`: `Css(light, dark)` from Lumen's tokens, and `Frame` and `NavItem`
  for the pages. `Docs(frame, title, description, nav, current, doc)` lays out side
  navigation, content and the page's contents. `LandingPage(frame, landing)` lays out a
  hero, actions, feature cards and more content. Pages have a skip link, landmarks,
  visible focus, and no scripts, cookies or third-party resources.

## Not yet

Forms and sessions, client-side rendering through the WebAssembly host, and request
handling on more than one connection at a time.

## Ports used

Net (`Serve`), FileSystem (static files, `Build`).
