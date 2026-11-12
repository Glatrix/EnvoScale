# 01-files

> **Status:** Compiles and runs with `envoc --lib` (M4).

Counts the words of a text file and names the most common one. It shows the standard
platform's layers working together:

- `std.env` for the arguments;
- `std.fs` to read the file (an `IoError` if it cannot);
- `alloc.map` to count;
- `core.text` to tell letters from the rest;
- `alloc.text` and `std.io` to print the result.

## Try it

```sh
build/stage2/envoc build --lib . examples/01-files/main.envo -o words
./words README.md
```

Without an argument it counts its own source. With `--os none` the file system is the
in-memory reference adapter, so `words` finds no file and exits with 1.

`envo.envon` is the package manifest (format: [`docs/spec/eon.md`](../../docs/spec/eon.md)).
