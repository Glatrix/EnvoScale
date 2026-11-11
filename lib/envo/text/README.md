# `envo.text`

> **Status:** Not started. Planned for **M4**. Tier when it lands: Experimental.

UTF-8 everywhere: Unicode segmentation, normalization and case mapping (tables generated from Unicode data files by an Envo tool), formatting, and a regex engine (linear-time by default, backtracking opt-in).

## Simple door

```envo
print("straße".ToUpper())
```

## Full-control door

Grapheme/word/sentence iterators, normalization forms, and `Regex` with an explicit engine choice.

## Ports used

none
