# `envo.prelude`

> **Status:** Not started. Until `envoc` compiles its own prelude, every Envo-S1 program
> gets the prelude Stage 1 embeds (`bootstrap/stage1/prelude/prelude.envo`): `IDrop`,
> `IEquatable`, `IHash`, `IClone`, `Option`, `Result`, `List` and `string`.

Names imported into every Envo file implicitly: `print`, `Option`, `Result`, `Ok`, `Err`, `List`, `string`, the primitive type aliases, and the core interfaces.
