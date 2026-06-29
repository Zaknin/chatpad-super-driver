# ChatpadFilter lifecycle tests

These tests compile the same portable lifecycle core source used by
`ChatpadFilter` into a native user-mode executable. They do not include WDF,
WDM, Windows driver headers, USB, HID, IOCTL, device handles, transport,
protocol, timers, work items, queues, packaging, signing, installation,
deployment, or hardware behavior.

The suite validates:

- neutral phase transitions from unset through created, prepared, D0 active,
  rundown requested, D0 stopped, and released;
- generation zero rejection, first D0 generation `1`, monotonic generation
  increments, and deterministic generation exhaustion failure;
- admission open only during the active D0 epoch;
- rundown closing admission before outstanding-operation checks;
- stale-generation acquire, release, rundown, and completion attempts that do
  not mutate current state;
- underflow, overflow, duplicate transition, and busy D0-exit behavior;
- snapshot determinism and the caller-owned, no-retained-pointer state shape.

Run both supported configurations from the repository root:

```powershell
.\tools\Test-ChatpadFilterLifecycle.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadFilterLifecycle.ps1 -Configuration Release -Platform x64
```

Expected result: one executable under
`artifacts\bin\x64\<Configuration>\ChatpadFilterLifecycleTests\`, deterministic
`Total`, `Passed`, and `Failed` assertion lines, `Failed: 0`, and no output
outside ignored `artifacts/`.
