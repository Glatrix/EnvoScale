# `envo.test`

> **Status:** Not started. Planned for **M5**. Tier when it lands: Experimental.

The test framework behind `envo test`: test discovery, assertions, snapshot/golden helpers, both AOT and script mode.

## Simple door

```envo
[Test] void Adds() => Assert.Equal(2, 1 + 1);
```

## Full-control door

Custom runners, fixtures and reporters.

## Ports used

Console, Clock
