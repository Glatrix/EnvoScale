# EON — Envo Object Notation (`.eon`)

> **Status:** Draft. First reader arrives with `envo.eon` (M5). The root `envo.eon` is
> kept valid against this draft.

EON is EnvoScale's data and configuration format: manifests, Lumen design tokens,
linker layouts, lockfiles. It is a **strict literal subset of Envo syntax**: an EON
document contains only literals, arrays and blocks, so it can never run code.

```eon
#eon 1
// envo.eon
package {
    name    = "hello"
    version = "0.1.0"
    edition = "2027"
}
dependencies {
}
targets { default = ["native", "wasm"] }
```

## 1. Lexical rules

EON uses chapter 1 of the language spec unchanged: UTF-8, the same comments (`//`,
nested `/* */`), the same string and number literals, and the same escapes.
Interpolated strings and raw strings are not allowed.

## 2. Grammar

```
Document = VersionLine? Entries
VersionLine = '#eon' IntLiteral LF          // must be the first line if present
Entries  = ( Entry Separator? )*
Entry    = Key '=' Value
         | Key Block                       // shorthand for Key = Block
Key      = Identifier | StringLiteral
Value    = StringLiteral | IntLiteral | FloatLiteral | 'true' | 'false' | 'null'
         | Array | Block
Array    = '[' ( Value ( Separator Value )* Separator? )? ']'
Block    = '{' Entries '}'
Separator = ',' | ';' | line break
```

**[eon.doc.1]** A document is a block without the braces: a sequence of entries.

**[eon.key.1]** Keys are identifiers (keywords allowed, since keys are never evaluated)
or string literals for keys that are not identifiers (`"content-type" = "text/html"`).
A key may appear at most once per block (duplicate keys are an error).

**[eon.order.1]** Entry order is preserved and significant to tools that rewrite files.

**[eon.num.1]** Integers are signed 64-bit unless a suffix says otherwise
(`size = 4096u64`); floats are `f64`. Type suffixes are allowed and checked.

**[eon.sep.1]** Entries and array elements are separated by `,`, `;` or line breaks.
Trailing separators are allowed.

## 3. Versioning

**[eon.ver.1]** A document may start with `#eon <n>` to state the EON syntax version.
Absent, the version is 1. Readers reject versions they do not know. This is EON's magic
header (brief §14.1); each schema built on EON (manifest, tokens, …) versions itself
separately with a field of its own.

## 4. Relationship to Envo

**[eon.envo.1]** An EON value, written after `=` in Envo code where the target type is
known, is a valid Envo initializer for that type: `[Derive(Eon)]` types round-trip
through EON, and `Config c = { name = "x", port = 8080 };` is valid Envo when `Config`
has those fields. Blocks are anonymous initializers; arrays are collection literals.

*Open question (RFC):* whether Envo accepts the `key { … }` shorthand in initializers,
or only `key = { … }`. EON accepts both.

## 5. Canonical form

`envo fmt` writes EON canonically: 4-space indentation, one entry per line, `=` aligned
within a block, no separators other than line breaks, a final newline. Readers accept any
valid layout.

## 6. Binary EON

A compact binary encoding (for caches and wire formats) is planned with `envo.eon` (M5).
It will start with the magic bytes `EON\0` and a version byte.
