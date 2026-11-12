# `tools/dbg`

> **Status:** M13. The debugger is `envo dbg` (`tools/envo/dbg.envo`,
> `runtime/vm/debug.envo`), in the `envo` binary.

`envo dbg [dir | file.envo] [-- args]` runs the program in the script runtime under a
source-level debugger (PLAN D65). It stops before the first line and reads commands
from stdin, one per line, so a session can be typed or scripted:

| Command | Does |
|---|---|
| `break [file:]line` (`b`) | a breakpoint (the file by the end of its path; the first file if none) |
| `continue` (`c`) | runs to the next breakpoint |
| `step` (`s`) | to the next line, into calls |
| `next` (`n`) | to the next line in this function or a caller, over calls |
| `finish` (`f`) | until this function returns |
| `bt` | the call stack, with each frame's line |
| `print name` (`p`), `locals` | a local of the current function, or all of them: integers, `bool`, `str`, pointers; other values by size |
| `list` (`l`), `where` | the lines around the current one, or the current one |
| `quit` (`q`) | ends the program |

At the end of input the program runs to its end without stopping.

**How:** the compiler marks every EIR instruction with its statement's file and line
(`EInst.Src`) and lists each function's named locals with the value that holds their
storage's address (`Module.Locals`). The VM checks before each instruction whether its
line changed and whether to stop. Lines in the runtime and prelude are never stopped at.

`tests/envo/dbg` holds a program, a session and its expected transcript, run by both
bootstrap scripts. Next: native debugging (DWARF and CodeView from `compiler/debuginfo`)
and the Debug Adapter Protocol for editors.
