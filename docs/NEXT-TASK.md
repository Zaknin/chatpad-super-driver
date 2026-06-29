# Next Task

## Exact current state

- **Completed branch:** `feature/transport-adapter-contract`.
- **Completed task starting commit:**
  `37326ec5cc9c3745ee692f9250904475de0af7dd`.
- **Completed commit message:** `feat: add mocked transport adapter contract`.
- **Transport library:** `src/transport/ChatpadTransport/ChatpadTransport.vcxproj`.
- **Transport tests:** `tests/transport/ChatpadTransportTests.vcxproj`.
- **Validation checkpoint:** transport tests pass `186/186` in Debug and
  Release; protocol direct tests pass `610/610`; kernel compatibility includes
  protocol plus transport as a `.lib`-only WDK build; driver compile-only
  regressions remain unsigned and disconnected from protocol/transport.
- **Safety checkpoint:** no WDF request, USB/HID operation, IOCTL, URB, device
  handle, endpoint/pipe assumption, INF/CAT/certificate/package/sign/install/
  deploy/load behavior, capture, timing, retry, readiness, response, or live
  hardware behavior exists in the transport layer.

## Next recommended objective

Create a non-installable KMDF lower-filter lifecycle scaffold with per-device
context, generation bookkeeping, admission stop, cancellation/rundown state,
and diagnostic logging stubs only.

The scaffold must not include INF/package/signing/install/load behavior, USB
request translation, hardware I/O, activation traffic, endpoint/pipe discovery,
continuous readers, VHF output, or keyboard semantics.

## Required branch and starting commit

- Create the next branch from the exact pushed
  `feature/transport-adapter-contract` commit named
  `feat: add mocked transport adapter contract`.
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
2. Inspect `src/driver/ChatpadFilter/` and prove the current skeleton before
   editing it.
3. Inspect `src/transport/ChatpadTransport/` and
   `tests/transport/README.md` to preserve the transport boundary.
4. Run repository safety and legacy immutability checks before editing.

## Safety restrictions

- Keep the task compile-only and non-installable.
- Do not add or modify INF, CAT, certificate, package, signing, installation,
  deployment, service, load, Device Manager, or live hardware behavior.
- Do not send USB/HID/control/input/output requests and do not open device or
  interface handles.
- Do not encode endpoint addresses, interface numbers, pipe ordinals, response
  bytes, acknowledgement, readiness, retry, timeout, or periodic-request
  semantics.
- Do not link `ChatpadTransport` or `ChatpadProtocol` into `ChatpadFilter`
  unless a later task explicitly authorizes that integration.
- Do not modify `legacy/`.
- Keep generated outputs under ignored `artifacts/`.

## Acceptance criteria

- The driver scaffold compiles Debug/Release as an unsigned `.sys` skeleton.
- Per-device context/generation/cancel/rundown bookkeeping is deterministic and
  contains no hardware I/O.
- `ChatpadFilter` still has no protocol/transport project references or linked
  protocol/transport sources.
- Existing protocol tests remain `610/610`; transport tests remain `186/186`;
  kernel compatibility remains `.lib` only; repository safety passes.
- Continuation docs accurately record the new state and no unsupported hardware
  capability is claimed.

## Inspect first

1. `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`
2. `src/driver/ChatpadFilter/driver.c`
3. `src/driver/ChatpadFilter/device.c`
4. `src/transport/ChatpadTransport/ChatpadTransportAdapter.h`
5. `tests/transport/README.md`
6. `tools/Build-Driver.ps1`
7. `tools/Test-RepositorySafety.ps1`
