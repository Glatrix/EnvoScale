# `envo.ui`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

Declarative, reactive component model (state, bindings, effects), layout (stack, grid, flex, constraints), accessibility tree, input, focus, animation, i18n. Renderers for desktop, web and terminal are adapters of the model.

## Simple door

```envo
window("Hello") { Text("Hello, World!") }
```

## Full-control door

Custom components, custom layout, custom renderers.

## Ports used

Window, Clipboard, plus the renderer's ports
