# 4. Items

> **Status:** Draft. Stage 0 implements the Envo-Core items (functions, structs,
> fieldless enums, constants) in M1. Tests: none yet (M1 adds `tests/spec/04-items/`).

Items are the declarations that make up a module: namespaces, imports, functions, types,
implementations and constants.

## 4.1 Files, modules and namespaces

**[item.mod.1]** A **package** is a folder with an `envo.envon` manifest. Its **modules**
are named by `snake_case` dotted paths (`envo.math`, `shapes.geometry`).

**[item.mod.2]** A file declares its module with a file-scoped namespace as its first
item: `namespace Shapes;`. Several files may share a namespace. A file without a
`namespace` belongs to the package's root module.

**[item.mod.3]** The **entry file** of a program may contain **top-level statements**
before or between items. They form the body of the program's implicit `main`. If any
top-level statement is `return e;` with an integer `e`, that is the exit code;
otherwise the exit code is 0. Only one file per program may have top-level statements.

## 4.2 Imports

```envo
use envo.math;                 // `math.sqrt(…)`
use envo.math.{sqrt, PI};      // `sqrt(…)`, `PI`
use envo.collections as col;   // `col.Map<…>`
```

**[item.use.1]** `use path;` makes the last path segment available as a name.
`use path.{a, b};` imports specific items. `use path as name;` renames. `use` is
file-scoped. `envo.prelude` is imported implicitly.

**[item.use.2]** `using` is reserved for scoped resource management (§4.10).

## 4.3 Visibility

**[item.vis.1]** Items and members are **private** by default: visible inside their
module (namespace) only. `internal` widens to the package; `public` to everyone.
`protected` is reserved.

**[item.vis.2]** In the standard platform, everything `public` has a stability tier
(`Experimental`, `Preview`, `Stable`); using an `Experimental` item requires
`--unstable` or an `[Unstable]` attribute on the using item.

## 4.4 Functions

```envo
[Inline] public static f32 Dot(in Vec3 a, in Vec3 b) => a.X * b.X + a.Y * b.Y + a.Z * b.Z;

public Result<string, IoError> ReadConfig(in string path) {
    var text = fs.ReadText(path)?;
    return Ok(text);
}
```

**[item.fn.1]** A function is `attributes? modifiers? ReturnType Name<Generics>?(Params) where? Body`.
The body is a block, or `=> expr` (with a `;` unless the newline rule ends it).

**[item.fn.2]** Parameters are `mode? Type name (= default)?`. Modes are `in` (shared
borrow), `ref` (exclusive borrow), `out` (must-initialize output), or none (by value:
move or copy). See chapter 5.

**[item.fn.3]** Arguments may be named at the call site (`Greet(name: "Ada")`). Named
arguments may follow positional ones; parameters with defaults may be omitted.

**[item.fn.4]** Modifiers: `public`/`internal`/`private`, `static`, `async`, `unsafe`
(the function may only be called in `unsafe` code), `const` (callable at compile time),
`extern "abi"` (foreign ABI: `"C"`, `"sysv64"`, `"win64"`).

## 4.5 Structs

```envo
public struct Point {
    public f32 X;
    public f32 Y;
    public f32 Length => math.sqrt(X * X + Y * Y);   // computed property
}
```

**[item.struct.1]** A struct body contains fields (`Type Name;` with an optional
`= default`), properties, methods, constructors, and nested items.

**[item.struct.2]** A struct may list interfaces it implements after `:`
(`struct Shape : IArea { … }`) and implement their methods in its body.

**[item.prop.1]** Properties: `Type Name { get; set; }` (auto-property backed by a
hidden field), `Type Name { get => …; set => …; }`, or the computed form
`Type Name => expr;`. `{ get; }` is read-only after construction; `init` allows setting
only in initializers.

## 4.6 Methods and `this`

**[item.method.1]** A method's receiver is declared like a parameter named `this`, first
in the list. Without one, the method borrows `this` shared (`in this`):

```envo
public f32 Length() => …;                  // in this (default)
public void Push(ref this, T item) { … }   // exclusive borrow
public Vec<T> IntoSorted(this) { … }       // takes ownership
public static Point Origin() => new Point { X = 0, Y = 0 };   // no receiver
```

*Rationale:* this reads like the existing parameter modes and avoids a separate
`mutating` keyword.

## 4.7 Enums

```envo
public enum Shape {
    Circle(Point center, f32 radius),
    Rect(Point min, Point max),
}
public enum Color : u8 { Red, Green = 5, Blue }
```

**[item.enum.1]** An enum's variants may carry positional or named payloads. A trailing
comma is allowed.

**[item.enum.2]** A **fieldless** enum may declare an integer representation (`: u8`)
and explicit discriminants. Otherwise discriminants start at 0 and count up.

**[item.enum.3]** Variants are accessed as `Shape.Circle(…)`, or unqualified wherever
the expected type is known (patterns, arguments, initializers).

## 4.8 Classes, interfaces and `impl`

```envo
public class Node {
    public string Name { get; set; }
    public List<Node> Children { get; } = new();
    public weak Node? Parent;
}

public interface IArea { f32 Area(); }

impl IArea for Shape {
    f32 Area() => match this { … };
}
```

**[item.class.1]** A class is a heap-allocated, reference-counted type. Fields are
mutable through any handle, under dynamic exclusivity checking (chapter 5, §5.6).
Classes do not support implementation inheritance; reuse goes through interfaces and
composition.

**[item.iface.1]** An interface declares method signatures (optionally with default
bodies), associated types and constants. By convention behaviour interfaces start with
`I` (`IArea`); auto-interfaces do not (`Copy`, `Sendable`, `Shareable`).

**[item.impl.1]** `impl I for T { … }` implements interface `I` for type `T`.
`impl T { … }` adds methods to `T` (an extension). Coherence: an `impl I for T` must
be in the package that defines `I` or the one that defines `T`.

## 4.9 Constants, statics and conditional compilation

**[item.const.1]** `const T NAME = expr;` declares a compile-time constant.

**[item.static.1]** `static T name = expr;` declares a global. Global mutable state
needs `unsafe` to access and is discouraged; use explicit context instead (brief §14.1).

**[item.cfg.1]** `#if cond … #elif … #else … #endif` includes items or statements when
the typed constant expression `cond` is true: `#if target.os == "windows"`.

## 4.10 Attributes

**[item.attr.1]** Attributes are written `[Name]` or `[Name(args)]` before an item,
member, parameter or statement. They are ordinary EnvoL types resolved by name.
Built-in ones include `Inline`, `NoInline`, `Cold`, `Hot`, `Pure`, `NoAlloc`, `Layout`,
`Align`, `Export`, `TargetFeature`, `Multiversion`, `Derive`, `Reflect`, `Test`,
`Unstable`, `Shader`. `Derive` runs hygienic generators written in EnvoL.

## 4.11 Envo-Core

**Core:** Envo-Core has functions (no generics, no default or named arguments, no
receivers), `struct` with public or private fields (no properties or methods),
fieldless `enum` with optional `: uN` representation and discriminants, `const` items,
`static` globals, and top-level statements in the entry file. It has no namespaces or
`use`: all files given to `envoc0` form one program with one global scope. See
[`envo-core.md`](envo-core.md).
