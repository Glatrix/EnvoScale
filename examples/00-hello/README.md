# 00-hello

> **Status:** Lexes with Stage 0 today. Compiles and runs once Stage 0's code generator
> lands (M1). Runs as a script from M6.

The smallest complete Envo program:

```envo
print("Hello, World!")
```

It is a valid program in both compiled and script mode: top-level statements are allowed
in the entry file, `print` comes from the implicit prelude, and no semicolon is needed at
the end of the file. It is also valid **Envo-Core**, which makes it the first program
Stage 0 will compile.

## Try it today

```sh
build/stage0/envoc0 lex examples/00-hello/main.envo
```

## When the toolchain exists

```sh
envo run examples/00-hello/main.envo     # script mode (M6)
envo build examples/00-hello             # native executable (M3/M5)
```

`envo.eon` is the package manifest (format: [`docs/spec/eon.md`](../../docs/spec/eon.md)).
