# The Envo Language Specification

> **Status:** Draft. Chapter 1 is **normative** (Stage 0 implements it and tests it).
> Chapters 2–5 are drafts that become normative as Stage 0–2 implement them.

## Chapters

| # | Chapter | Status |
|---|---|---|
| 1 | [Lexical structure](01-lexical.md) | Normative; implemented by Stage 0 |
| 2 | [Types](02-types.md) | Draft |
| 3 | [Expressions and statements](03-expressions.md) | Draft |
| 4 | [Items](04-items.md) | Draft |
| 5 | [Ownership and borrowing](05-ownership.md) | Draft |

## Companion specifications

| Document | Defines | Status |
|---|---|---|
| [`envo-core.md`](envo-core.md) | **Envo-Core**, the subset compiled by Stage 0 | Implemented by Stage 0 (M1) |
| [`envo-s1.md`](envo-s1.md) | **Envo-S1**, the subset compiled by Stage 1 | Draft; being implemented (M2) |
| [`eon.md`](eon.md) | **EON**, Envo Object Notation (`.envon`) | Draft |
| [`eir.md`](eir.md) | **EIR**, the Envo intermediate representation | Version 1 specified ([RFC 0005](../rfcs/0005-eir-v1.md)); being implemented (M2) |
| [`errors.md`](errors.md) | Registry of diagnostic codes | Live |

## Conventions

- **Rule IDs.** Every normative rule has a stable ID in brackets, e.g. **[lex.ws.1]**.
  IDs never change meaning; a removed rule's ID is retired, not reused.
- **Tests.** Each rule lists the tests that verify it. A rule with no tests says
  "Tests: none yet" and names the milestone that adds them. Paths are relative to the
  repository root.
- **"must", "must not", "may"** have their usual normative meanings. Text marked
  *Note* or *Rationale* is informative.
- **Grammar** uses this notation: `'x'` is a literal, `A B` sequence, `A | B` choice,
  `A?` optional, `A*` zero or more, `A+` one or more, `( … )` grouping,
  `[a-z]` a character range, `~X` any character except X.
- **Editions.** Text applies to every edition unless it says otherwise. The first
  edition is `"2027"`.
- **Envo-Core marks.** Paragraphs marked **Core:** describe how Envo-Core restricts the
  rule. Every Envo-Core program is a syntactically valid Envo program.
