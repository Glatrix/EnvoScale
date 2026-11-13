# Examples

Small programs, one idea each. Each folder is a package: `cd` into it and run `envo run .`;
CI runs every one, as a script and natively, and checks its output against `output.txt`.

| | |
|---|---|
| [`00-hello`](00-hello) | The smallest program: one line, no `main` needed. |
| [`01-words`](01-words) | Reads a file and counts its words: `std.fs`, a hash map, and string building. |
| [`02-shapes`](02-shapes) | Enums with data, `match` as an expression, a struct with a method, and `foreach`. |
| [`03-generics`](03-generics) | An interface, two structs that implement it, and a generic function constrained by it. |
| [`04-json`](04-json) | Parses a JSON document, reads a field, changes it, and writes it back. |
| [`05-crypto`](05-crypto) | A SHA-256 digest, and an Ed25519 signature that catches a changed message. |
