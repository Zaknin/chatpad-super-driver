# Project State

*Last updated: 2026-06-30T00:00+04:00*

## Current state

- **Branch:** `analysis/kmdf-transport-bridge-design`.
- **Starting checkpoint:** `e3729efbcdd2891bfcb3a427b82e4be7c99d8d16`.
- **Expected task commit:** `docs: design kmdf transport adapter bridge`.
- **KMDF transport-bridge design:** completed in
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`.
- **Selected ownership strategy:** one future per-device KMDF transport owner
  under `WDFDEVICE` owns bridge bookkeeping, bounded activation transport state,
  request-owner records, future target references, scheduler state, diagnostics,
  and separate continuous-input state. No global mutable device state is
  allowed.
- **Selected synchronization strategy:** first implementation should use a
  per-device `WDFSPINLOCK` for short lifecycle/bridge/request-table,
  completion-once, cancellation, generation, scheduler-state, and diagnostic
  transitions. Passive work may later orchestrate passive-only operations, but
  the portable lifecycle core remains externally serialized and not internally
  thread-safe.
- **Lifecycle/generation integration:** PrepareHardware initializes bridge
  bookkeeping only; D0Entry starts one nonzero lifecycle generation and
  initializes bounded activation transport state for that generation; D0Exit
  closes admission before cancellation and delay scheduling; completions release
  lifecycle outstanding counts exactly once; ReleaseHardware requires completed
  rundown before clearing future ownership.
- **Request ownership model:** future WDF requests are owned by a
  generation-bound per-device request-owner record that maps a portable
  `ChatpadTransportOperationToken` to one WDF request without pointer aliasing.
  Stale and duplicate completions are rejected by stored generation, token, and
  completion-once state.
- **Delay metadata:** the six 12 ms after-step values remain metadata. A future
  per-device scheduler owns them only after prior request completion policy
  permits progression. Blocking sleep is rejected.
- **Activation versus continuous input:** activation remains the existing
  bounded six-request/six-delay flow. The transport adapter's 64-operation
  model is not suitable for continuous input; repeated reads require a
  separate generation-bound input owner and separate evidence.
- **Driver/source state:** no source, project, solution, INF, CAT, package,
  service, installer, certificate, signing, deployment, or runtime driver
  behavior changed for this documentation-only task.
- **Safety:** no device/controller enumeration, handle open, USB/HID/IOCTL/URB,
  endpoint/pipe access, WDF target, WDF request, queue, timer, work item,
  continuous reader, thread, ETW, capture, elevation, installation, load,
  signing, package, deployment, or hardware test occurred. `legacy/` remains
  immutable; generated outputs remain ignored under `artifacts/`.

## Unresolved blockers

- No Windows 11 default-control-pipe access is proven.
- No modern input endpoint, pipe, interface, request path, or transfer
  ownership is proven.
- No INF establishes device-specific lower-filter installation beneath
  `xusb22`.
- Control-IN response bytes, acknowledgement, readiness, retry, timeout,
  activation success, continuous input, and keyboard presentation remain
  unresolved.
- Runtime implementation remains blocked on synchronization, request ownership,
  pure translation, compile-only WDK formatting, lifecycle race tests,
  installation recovery, stack visibility, and explicit authorization gates.
