# `envo.ai`

> **Status:** Not started. Planned for **M12**. Tier when it lands: Experimental.

Tensors (f32/f16/bf16/int8/int4), CPU and GPU kernels, autograd, layers, optimizers, tokenizers, model loading (safetensors-style, GGUF-style, native `.envomodel`), quantization, inference serving, embeddings and an HNSW index.

## Simple door

```envo
print(ai.Load("tiny.gguf").Ask("Say hello"))
```

## Full-control door

Tensor-level control, custom kernels in Envo through `GpuDevice`, custom samplers.

## Ports used

GpuDevice, Threads, FileSystem
