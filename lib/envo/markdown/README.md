# `envo.markdown`

> **Status:** Experimental (M9.4). Tests: `lib/envo/markdown/tests/`.

Markdown to HTML (PLAN D51): the parts of CommonMark that documents use, and GitHub's
tables.

- **Blocks:** ATX and setext headings, paragraphs, fenced and indented code, block
  quotes, bullet and ordered lists (nested, tight or loose), thematic breaks, tables
  with alignment.
- **Inlines:** code spans, emphasis and strong emphasis (`_` only at word boundaries, so
  `snake_case` stays text), links, images, autolinks, backslash escapes, entities and
  hard line breaks.

Text is always escaped. Raw HTML is escaped too unless the document is trusted
(`Options.Site()`), and `javascript:` and similar links become `#`. Every heading gets a
unique id, and the document lists its headings, so a page can show its contents. The
EnvoScale website renders every Markdown file in the repository with it.

## Simple door

```envo
use envo.markdown;

print(markdown.ToHtml("# Hello\n\n*Hello*, World!").AsStr());
```

## Full-control door

`Render(text, Options)` gives a `Doc`: `HtmlOf`, `Title`, `HeadingList` (level, text,
id). `Options.Safe()` escapes raw HTML; `Options.Site()` passes it through and rewrites
links to `x.md` as `x.html`. `Slug(text)` and `Escape(ref html, text)` are public.

## Not yet

Reference-style links (`[a][b]`), footnotes, task lists and strikethrough.

## Ports used

None.
