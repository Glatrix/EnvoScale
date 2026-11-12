# website/

The EnvoScale website, **written in Envo** ([`PLAN.md`](PLAN.md); PLAN D52).
[`site.envo`](site.envo) renders the home page with Lumen's Landing template, and every
Markdown document in the repository with the Docs template. Pages keep the repository's
paths, so `docs/spec/eir.md` becomes `docs/spec/eir.html` and the documents' links to
each other keep working. All links are relative, so the site works at any address.

From the repository's root:

```sh
envoc build -O2 --lib . website/site.envo -o build/site-tool
build/site-tool build            # the static site in build/site
build/site-tool serve 8080       # the same pages, rendered per request
```

The bootstrap scripts build the site and check its pages. Publishing it (a domain and
hosting) is the owner's decision (#61).
