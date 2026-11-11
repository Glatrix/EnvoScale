# `envo.bench`

> **Status:** Not started. Planned for **M5**. Tier when it lands: Experimental.

The benchmark framework behind `envo bench`, with tracked baselines so regressions fail CI.

## Simple door

```envo
[Bench] void Sort(ref Bencher b) => b.Run(() => data.Sort());
```

## Full-control door

Custom measurement, statistics and output formats.

## Ports used

Clock
