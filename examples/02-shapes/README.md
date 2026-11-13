# shapes

Enums with data, `match` as an expression, a struct with a method, and `foreach`.

```cs
use alloc.text;

enum Shape {
    Circle(i64 radius),
    Rect(i64 width, i64 height),
}

i64 Area(in Shape s) => match s {
    Circle(r) => 3 * r * r,
    Rect(w, h) => w * h,
};

struct Stats {
    i64 Total;
    i64 Largest;

    public void Add(ref this, i64 area) {
        this.Total += area;
        if (area > this.Largest) this.Largest = area;
    }
}

List<Shape> shapes = List<Shape>.New();
shapes.Push(Shape.Circle(2));
shapes.Push(Shape.Rect(3, 4));
shapes.Push(Shape.Rect(5, 1));

Stats stats = new Stats { Total = 0, Largest = 0 };
foreach (var s in shapes.AsSlice()) stats.Add(Area(s));

string line = string.From("total ");
line.Append(text.Int(stats.Total).AsStr());
line.Append(", largest ");
line.Append(text.Int(stats.Largest).AsStr());
print(line.AsStr());
```

```
$ envo run .
total 29, largest 12
```
