# generics

An interface, two structs that implement it, and a generic function constrained by it.

```cs
use alloc.text;

interface IShape {
    i64 Area(in this);
    str Name(in this);
}

struct Square : IShape {
    i64 Side;

    public i64 Area(in this) => this.Side * this.Side;
    public str Name(in this) => "square";
}

struct Triangle : IShape {
    i64 Base;
    i64 Height;

    public i64 Area(in this) => this.Base * this.Height / 2;
    public str Name(in this) => "triangle";
}

// One copy of Describe is made for each type it is called with: no virtual calls.
void Describe<T>(in T shape) where T : IShape {
    string line = string.From(shape.Name());
    line.Append(": ");
    line.Append(text.Int(shape.Area()).AsStr());
    print(line.AsStr());
}

Describe(new Square { Side = 4 });
Describe(new Triangle { Base = 6, Height = 7 });
```

```
$ envo run .
square: 16
triangle: 21
```
