# `envo.ai`

> **Status:** Experimental (M12). Tensors, autograd, optimizers, tokenizers, GGUF
> loading, local inference for the Llama family, text embeddings, vector search and a
> GPU matrix product.

## Simple door

```envo
print(ai.Load("tiny.gguf").Ask("Say hello").AsStr());
```

`ai.Load` reads a GGUF model (llama, mistral, qwen2 or qwen3 architecture) and `Ask`
answers in the model's chat format when its file names one (ChatML, Llama 3, `[INST]` or
Zephyr; Qwen 3's thinking is turned off). No model ships with EnvoL: point it at one you
have the right to use.

## Full-control door

| Part | What it is |
|---|---|
| `Tensor` | dense row-major `f32` (rows × cols): `Zeros`, `Of`, `Random` (seeded), `MatMul`, `Transpose`, `Sum`, `ArgMax` |
| `Graph` | define-by-run autograd (D57): `Leaf`, `MatMul`, `AddRow` (bias), `Add`, `Mul`, `Relu`, `Tanh`, `Sigmoid`, `Mse`, `SoftmaxCrossEntropy`; `Backward(loss)`, then `Grad(id)` |
| `Sgd`, `Adam` | optimizers over a tensor and its gradient |
| `Rng` | a seeded generator (xorshift64*): the same weights everywhere |
| `envo.ai.tokenizer` | byte-level BPE (GPT-2's alphabet and word split), SentencePiece-style merges with byte fallback, and WordPiece (D58); `Train` learns byte-level BPE from a corpus; special tokens match whole |
| `envo.ai.gguf` | GGUF v2/v3 files (D59): metadata, the tensor table, and F32, F16, BF16, Q8_0, Q4_0, Q4_1, Q5_0, Q5_1, Q4_K, Q5_K and Q6_K tensors as `f32`; every count and offset checked. `Writer` makes files (F32, F16, Q8_0) |
| `Model` | the transformer (D60): `Load`/`From`, `NewContext`, `Next` (one token, returns the logits), `Pick`, `Generate`, `Complete`, `Ask`, `SetTemperature` (0 is greedy; above 0 samples from a seeded generator), `SetMaxTokens`. The weights are read-only; a `Context` holds one sequence's attention cache |
| `Encoder` | a text encoder (D62): nomic-bert (nomic-embed-text) from GGUF; `Embed(text)` gives a unit-length vector (mean-pooled). Use the model's task prefixes (`search_query: `, `search_document: `) |
| `Cosine`, `Normalized` | vector similarity |
| `Index` | exact nearest neighbours by cosine |
| `Hnsw` | approximate nearest neighbours (a hierarchical navigable small world graph): `New(dim, m, ef, seed)`, `Add`, `Nearest`, `SetEf`; deterministic for a seed |
| `MatMulOn(dev, a, b)` | the matrix product on a device through `IGpu` (D61): Direct3D 12 compute on Windows, the CPU elsewhere |

Training, tokenizing and inference are IEEE arithmetic in EnvoL, so a program gives the
same numbers at -O0, at -O2, in the script runtime and in WebAssembly.

## How it is tested

- `tests/train.envol`: a network learns XOR (Adam), a gradient matches a finite
  difference, a softmax classifier learns three classes (SGD).
- `tokenizer/tests/bpe.envol`: training, round trips for any bytes, SentencePiece merges
  and byte fallback.
- `gguf/tests/gguf.envol`: files written and read back, half precision (every finite
  value round trips), the block formats against values worked by hand, malformed files
  refused.
- `tests/llm.envol`: two tiny models made by `tests/mkmodel.py` (llama-style and
  qwen3-style, with random weights) run through `Model` and match a numpy reference
  of the same architecture: the logits after a prompt and greedy generation.
- `tests/search.envol`: a tiny nomic-bert model (also from `mkmodel.py`) matches its
  numpy reference (tokens and embedding); HNSW's recall against the exact index.
- `tests/train.envol` also checks the device product against the CPU's.

Checked by hand on a real model: nomic-embed-text v1.5 (Q4_K_M, from LM Studio) loads,
its WordPiece ids are BERT's, and it ranks texts sensibly ("What is a kitten?" against
"A kitten is a young cat." 0.86, "Puppies are young dogs." 0.58, a stock-market
sentence 0.47). Chat inference has not been checked against a real chat model: that
needs a model file, which is the owner's choice (STATUS).

## Limits

- Weights are dequantized to `f32` on load: four bytes per parameter. Computing on
  quantized blocks, and running whole models on the GPU, come next.
- One thread, scalar code: a 137M-parameter encoder takes seconds per sentence. Threads
  come with the `Threads` port; SIMD with `envo.simd`.
- The WordPiece tokenizer lowercases ASCII and does not strip accents.
- Chat templates are recognized by their markers, not run (no Jinja).

## Ports used

FileSystem (loading), GpuDevice (`IGpu`, for `MatMulOn`). Threads follow.
