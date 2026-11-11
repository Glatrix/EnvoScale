# `envo.image`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

PNG, JPEG, QOI and WebP decoding (and encoding where reasonable).

## Simple door

```envo
var img = image.Load("cat.png")?;
```

## Full-control door

Streaming decoders, pixel format control, colour management.

## Ports used

FileSystem (only via the convenience loaders)
