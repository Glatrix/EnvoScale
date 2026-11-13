# `tests/fuzz` — fuzz targets

> **Status:** M13. Run by both bootstrap scripts (`test`, "fuzz targets") for a few
> hundred runs each; run them longer by hand.

Each target is a program for `envo fuzz` (`tools/fuzz/README.md`): it reads the file
named by its first argument and feeds its bytes to a parser that faces untrusted input.
A panic is a bug.

| Target | Feeds | Found when first fuzzed (M13), now fixed and tested |
|---|---|---|
| `json.envol` | `envo.json.Parse`, then `Write` | invalid UTF-8 after a number panicked (`lib/envo/json/tests/hostile.envol`) |
| `eon.envol` | `envo.eon.Parse`, then `Write` | nothing in 3,000 runs |
| `markdown.envol` | `envo.markdown.ToHtml` | an empty list item (`-` alone) indexed out of bounds; bytes that are not UTF-8 panicked (now replaced by U+FFFD) (`lib/envo/markdown/tests/hostile.envol`) |
| `http.envol` | `envo.http.ParseRequest`, `ParseResponse` | bytes that are not UTF-8 in the head or body, a huge Content-Length and a huge chunk size panicked: a remote crash of `envo.web` servers (`lib/envo/http/tests/hostile.envol`) |
| `gguf.envol` | `envo.ai.gguf.File.Parse`, every tensor and key | nothing in 1,500 runs |
| `tokenizer.envol` | `Tokenizer.Train`, `Encode`, `Decode` (must round trip) | bytes that are not UTF-8 panicked (`lib/envo/ai/tokenizer/tests/bytes.envol`) |

`corpus/<target>` holds the first inputs. The fuzzer adds the inputs it finds to the
corpus folder it is given, so give it a copy:

```
cp -r tests/fuzz/corpus/json build/corpus-json
envo fuzz tests/fuzz/json.envol --corpus build/corpus-json --runs 100000
```
