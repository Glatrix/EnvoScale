# words

Reads a file and counts its words: `std.fs`, a hash map, and string building.

```cs
use std.fs;
use std.env;
use alloc.map.{Map};
use alloc.text;
use core.text as ct;

str path = "poem.txt";
if (env.ArgCount() > 1) path = env.Arg(1);
var read = fs.ReadText(path);
if (read.IsErr()) {
    print("cannot read the file");
    return 1;
}
string content = read.Unwrap();
str all = content.AsStr();

// a word is a run of letters and digits
Map<str, u64> counts = Map<str, u64>.New();
u64 total = 0;
usize i = 0;
while (i < all.Len) {
    while (i < all.Len && !ct.IsAlnum(all[i])) i++;
    usize start = i;
    while (i < all.Len && ct.IsAlnum(all[i])) i++;
    if (i > start) {
        str word = all[start..i];
        counts.Set(word, counts.GetOr(word, 0) + 1);
        total++;
    }
}

str best = "";
u64 most = 0;
foreach (var w in counts.Keys().AsSlice()) {
    u64 n = counts.GetOr(w, 0);
    if (n > most || (n == most && ct.Compare(w, best) < 0)) {
        most = n;
        best = w;
    }
}

string line = text.Uint(total);
line.Append(" words, ");
line.Append(text.Uint(counts.Len() as u64));
line.Append(" different; the most common is \"");
line.Append(best);
line.Append("\"");
print(line.AsStr());
```

```
$ envo run --allow read .
22 words, 13 different; the most common is "the"
```
