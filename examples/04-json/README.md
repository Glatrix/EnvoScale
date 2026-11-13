# json

Parses a JSON document, reads a field, changes it, and writes it back.

```cs
use envo.json;

str doc = "{\"name\": \"envol\", \"version\": 5, \"tags\": [\"fast\", \"small\"]}";
json.Value v = json.Parse(doc).Unwrap();
print(v.GetStr("name") ?? "no name");

v.Set("stable", json.Value.OfBool(false));
print(json.Write(v).AsStr());
```

```
$ envo run .
envol
{"name":"envol","version":5,"tags":["fast","small"],"stable":false}
```
