# Port conformance suites

> **Status:** M4, M5: one suite per port in `lib/ports` (`filesystem/`, `console/`,
> `clock/`, `entropy/`, `environment/`, `process/`).

Each suite is a program that gets its adapter from `platform` and checks what the port
promises, printing only failures and a final line. The test scripts run every suite
against the reference adapters (`envoc --os none`) and the native ones, at `-O0` and
`-O2`, on Windows and Linux in CI. Passing them is what makes an adapter complete (see
`docs/porting/CHECKLIST.md`); `envo port check <adapter>` will run them from M5.
