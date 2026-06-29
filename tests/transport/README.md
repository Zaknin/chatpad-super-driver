# ChatpadTransport tests

The transport tests are native, deterministic, and offline. They validate:

- caller-owned transport state initialization and generation changes;
- cancellation and stale-generation rejection;
- value-copy operation tokens;
- deterministic activation-plan emission through the existing protocol executor;
- fixed-capacity mock sink rejection;
- operation completion classification.

The mock sink in `fixtures\ChatpadTransportMock.h` is test-only. It records
operations in a bounded array and can reject at a chosen sequence number or
capacity boundary.

Run:

```powershell
.\tools\Test-ChatpadTransport.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadTransport.ps1 -Configuration Release -Platform x64
```

Expected result: one executable under `artifacts\bin\x64\<Configuration>\ChatpadTransportTests\`,
deterministic `Total`, `Passed`, and `Failed` assertion lines, `Failed: 0`,
and no output outside `artifacts/`.
