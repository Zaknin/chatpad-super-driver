# Next Task

## Exact current state

- **Completed branch:** `analysis/kmdf-transport-bridge-design`.
- **Completed task starting commit:**
  `e3729efbcdd2891bfcb3a427b82e4be7c99d8d16`.
- **Completed commit message:** `docs: design kmdf transport adapter bridge`.
- **Authoritative design document:**
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`.
- **Bridge decision:** a future per-device KMDF transport owner under
  `WDFDEVICE` owns request records, bounded activation bridge state, scheduler
  state, diagnostics, future target references, and separate continuous-input
  state. WDF requests are tied to one nonzero D0 generation through a
  generation-bound request-owner record and a portable
  `ChatpadTransportOperationToken`.
- **Synchronization decision:** first coding should assume a per-device
  `WDFSPINLOCK` for short shared-state transitions. The existing lifecycle core
  remains externally serialized and must not be treated as internally
  thread-safe.
- **Safety checkpoint:** no runtime transport behavior, source/project changes,
  WDF request/target/queue/timer/work-item behavior, USB/HID/IOCTL/URB/device
  access, endpoint/pipe selection, INF/CAT/package/signing/deployment/load, or
  hardware action exists.

## Next recommended objective

Create a pure, compile-tested Windows control-setup translation module that maps
the six neutral `ChatpadActivationRequest` descriptors into a caller-owned
inspectable setup representation.

The module must stay WDF-independent and offline-testable. It may model setup
fields and payload metadata, but it must not create a `WDFDEVICE`,
`WDFIOTARGET`, `WDFREQUEST`, USB target, request formatter, queue, timer, work
item, endpoint, pipe, INF, CAT, package, signing path, install path, deployment
path, load path, or hardware behavior.

## Required branch and starting commit

- Create the next branch from the exact pushed
  `analysis/kmdf-transport-bridge-design` commit named
  `docs: design kmdf transport adapter bridge`.
- Require a clean tree and verify:

```powershell
git status --short --branch
git branch --show-current
git rev-parse HEAD
git merge-base --is-ancestor 6502452 HEAD
```

The prohibited-ancestor check must exit `1`; exit `0` is a hard stop.

## Preconditions

1. Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, and the latest relevant `docs/WORKLOG.md` entries.
2. Read `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`,
   `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`, and `docs/CHATPAD-PROTOCOL.md`.
3. Inspect `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h/.c`,
   `src/protocol/ChatpadProtocol/ChatpadActivationSequence.h/.c`, and the
   protocol tests.
4. Inspect the WDK kernel compatibility project and wrapper before deciding
   where the new compile-only proof belongs.
5. Run repository safety and confirm `legacy/` is unchanged before editing.

## Safety restrictions

- Keep the task offline and compile/test only.
- Do not add WDF targets, WDF requests, request formatting/submission,
  completion callbacks, queues, timers, work items, threads, USB/HID/IOCTL/URB
  behavior, endpoint/pipe/interface discovery, device handles, SetupAPI,
  Configuration Manager, WinUSB, ETW, capture, or hardware access.
- Do not implement responses, readiness, acknowledgement, retries, timeouts,
  activation success, continuous input, or key mapping.
- Do not add INF, CAT, service, installer, package, certificate, signing,
  deployment, loading, or recovery scripts.
- Do not modify `legacy/`.
- Keep generated outputs under ignored `artifacts/`.

## Acceptance criteria

- All six activation descriptors map to exact caller-owned setup/payload
  representations.
- `09 00` is present only for the confirmed host-to-device activation payload.
- `90 00` remains absent.
- Device-to-host descriptors expose expected inbound byte count but no
  fabricated response bytes.
- Translation remains WDF-independent and does not imply default-control access
  or request submission.
- Offline tests cover exact fields, invalid inputs, value-copy behavior,
  payload bounds, direction, and absence of acknowledgement/readiness/retry
  semantics.
- Kernel compile validation remains static-library only and produces no `.sys`,
  INF, CAT, package, signing, install, deployment, load, or hardware output.

## Inspect first

1. `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`
2. `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`
3. `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h`
4. `src/protocol/ChatpadProtocol/ChatpadActivationRequests.c`
5. `tests/protocol/ChatpadProtocolTests.c`
6. `tests/kernel/ChatpadProtocolKernelCompileCheck/`
7. `tools/Test-ChatpadProtocol.ps1`
8. `tools/Test-ChatpadProtocolKernelCompatibility.ps1`
