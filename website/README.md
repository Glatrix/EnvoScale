# website/

The EnvoScale website, **written in Envol** ([`PLAN.md`](PLAN.md); PLAN D52).
[`site.envol`](site.envol) renders the home page with Lumen's Landing template, and every
Markdown document in the repository with the Docs template. Pages keep the repository's
paths, so `docs/spec/eir.md` becomes `docs/spec/eir.html` and the documents' links to
each other keep working. All links are relative, so the site works at any address.

From the repository's root:

```sh
envoc build -O2 --lib . website/site.envol -o build/site-tool
build/site-tool build            # the static site in build/site
build/site-tool serve 8080       # the same pages, rendered per request
```

The **sandbox** (`/sandbox/`) is the compiler itself, built for WebAssembly as
`build/envoc.wasm`:

```sh
cd compiler && ../build/stage2/envoc build -O2 --target wasm32-web $(grep -v '^#' files.txt) -o ../build/envoc.wasm
```

It compiles and runs programs in the visitor's browser, so nothing they type leaves their
machine (`adapters/interop/js/sandbox.js`). The site includes it when
`build/envoc.wasm` exists. The bootstrap scripts build both, and check the pages and the
sandbox's files. Publishing it (a domain and
hosting) is the owner's decision (#61).
