# Next Task

## Exact current state

- **Completed branch:** `feature/kmdf-lifecycle-scaffold`.
- **Completed task starting commit:**
  `29c3fc1a55ded35c8e33f6ceb88e2a434334ef9a`.
- **Completed commit message:** `feat: add kmdf lifecycle scaffold`.
- **Driver scaffold:** `ChatpadFilter` is a compile-only, non-installable KMDF
  filter-capable skeleton. It calls `WdfFdoInitSetFilter(DeviceInit)`, creates
  a per-device context, and registers only prepare/release hardware plus D0
  entry/exit callbacks.
- **Lifecycle core:** `src/driver/ChatpadFilter/ChatpadFilterLifecycle.h/.c`
  is portable C with caller-owned state, neutral phases, nonzero D0 generation
  epochs, admission/rundown bookkeeping, stale-generation rejection, snapshots,
  and no allocation, I/O, WDF, WDM, Windows, USB, HID, IOCTL, request, queue,
  endpoint, pipe, timer, work item, protocol, or transport dependency.
- **Lifecycle tests:** `tools/Test-ChatpadFilterLifecycle.ps1` builds and runs
  `tests/driver/ChatpadFilterLifecycleTests/`; current assertion total is
  `109/109` in Debug and Release.
- **Validation checkpoint:** protocol direct tests pass `610/610`; protocol
  project regressions pass `610/610` in Debug and Release; transport tests
  pass `186/186` in Debug and Release; kernel compatibility remains `.lib`
  only; driver builds pass Debug/Release, remain unsigned, and compile
  lifecycle source into the driver without protocol/transport linkage.
- **Safety checkpoint:** no INF, CAT, certificate, package, installer, service,
  signing, deployment, load, device/interface open, USB/HID/IOCTL/URB request,
  endpoint/pipe assumption, input reader, activation traffic, timer, work item,
  thread, retry, response, readiness, semantic key mapping, VHF output, or live
  hardware behavior exists.

## Next recommended objective

Create a documentation-only design for the future Windows KMDF transport
adapter bridge between the existing neutral `ChatpadTransport` contract and a
future per-device KMDF request owner.

The next task should define object ownership, cancellation ordering,
generation-token propagation, and compile-only boundaries. It must not submit
or format USB requests, create queues, discover endpoints, install a driver,
or connect the bridge to runtime hardware.

## Required branch and starting commit

- Create the next branch from the exact pushed
  `feature/kmdf-lifecycle-scaffold` commit named
  `feat: add kmdf lifecycle scaffold`.
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
2. Inspect `src/driver/ChatpadFilter/ChatpadFilterLifecycle.h/.c`,
   `src/driver/ChatpadFilter/device.c`, and `src/driver/ChatpadFilter/README.md`.
3. Inspect `src/transport/ChatpadTransport/ChatpadTransportAdapter.h/.c` and
   `tests/transport/README.md`.
4. Run repository safety, lifecycle Debug/Release tests, and legacy
   immutability checks before editing.

## Safety restrictions

- Keep the next task documentation-only unless explicitly authorized otherwise.
- Do not add INF, CAT, certificate, package, signing, installation,
  deployment, service, load, Device Manager, or live hardware behavior.
- Do not send, format, or queue USB/HID/control/input/output requests and do
  not open device or interface handles.
- Do not encode endpoint addresses, interface numbers, pipe ordinals, response
  bytes, acknowledgement, readiness, retry, timeout, or periodic-request
  semantics.
- Do not link `ChatpadTransport` or `ChatpadProtocol` into `ChatpadFilter`
  unless a later task explicitly authorizes runtime integration.
- Do not modify `legacy/`.
- Keep generated outputs under ignored `artifacts/`.

## Acceptance criteria

- The design preserves the current lifecycle generation/admission boundary.
- The design identifies where future cancellation and completion translation
  would occur without creating runtime behavior.
- `ChatpadFilter` remains compile-only, unsigned, non-installable, and
  disconnected from protocol/transport runtime linkage.
- Existing protocol, transport, lifecycle, kernel compatibility, driver, and
  repository safety checks remain passable.
- Continuation docs make no unsupported hardware capability claim.

## Inspect first

1. `src/driver/ChatpadFilter/ChatpadFilterLifecycle.h`
2. `src/driver/ChatpadFilter/ChatpadFilterLifecycle.c`
3. `src/driver/ChatpadFilter/device.c`
4. `src/driver/ChatpadFilter/README.md`
5. `src/transport/ChatpadTransport/ChatpadTransportAdapter.h`
6. `tests/driver/ChatpadFilterLifecycleTests/README.md`
7. `tools/Test-ChatpadFilterLifecycle.ps1`
