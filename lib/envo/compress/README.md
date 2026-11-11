# `envo.compress`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

DEFLATE/zlib/gzip, an LZ4-style codec, and a Zstandard-compatible codec.

## Simple door

```envo
var packed = compress.Gzip(data);
```

## Full-control door

Streaming encoders/decoders with explicit levels, windows and dictionaries.

## Ports used

none
