# `envo.cli`

> **Status:** Experimental (M8.2). Tests: `lib/envo/cli/tests/`.

Command-line programs: commands, flags and positional arguments with generated help;
tables and progress bars for output. Pure text (it takes the arguments as a list and
gives text back), so it runs, and is tested, anywhere.

## Simple door

```envo
use envo.cli;
use std.env;

cli.App app = cli.App.New("greet", "Says hello.");
app.Flag("name", 'n', "who to greet", "World");
List<str> args = env.Args();
cli.Parsed p = app.Parse(args.AsSlice());
if (p.WantsHelp()) write(1, app.Help("").AsStr());
else print(p.Value("name"));
```

The brief's `[Command("greet")] void Greet(string name = "World")` needs attributes
and reflection, which Envo-S1 does not have; it becomes sugar over this door.

## Full-control door

- `App`: `Flag`, `Switch`, `Command`, `CommandFlag`, `CommandSwitch`, `CommandArg`,
  `Parse`, `Help`.
- `Parsed`: `CommandName`, `Value`, `On`, `ArgCount`, `Arg`, `ErrorText`, `WantsHelp`.
  Flags as `--name value`, `--name=value` or `-n value`; `--` ends the flags.
- `Table` (`Row("a|b|c")`, `Render`), `ProgressBar(done, total, width)`.

Colors, prompts and spinners come with `envoui.term` (M8.1).

## Ports used

none
