# `envo.gpu`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

The explicit GPU layer: devices, queues, buffers, textures, pipelines, bind groups, command encoders, sync. The software adapter is mandatory and must pass every test.

## Simple door

```envo
var gpu = gpu.Default();
```

## Full-control door

Everything Vulkan/Metal/D3D12/WebGPU have in common, with no hidden state.

## Ports used

GpuDevice
