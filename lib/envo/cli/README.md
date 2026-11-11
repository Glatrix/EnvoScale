# `envo.cli`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

Declarative argument parsing from attributes (subcommands, help, completion scripts, validation), prompts, progress bars, spinners and tables.

## Simple door

```envo
[Command] void Greet(string name = "World") => print($"Hello, {name}!")
```

## Full-control door

Build the argument parser by hand; custom help renderers.

## Ports used

Console
