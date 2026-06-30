# Next Task

## Current state

- Current branch after this checkpoint:
  `feature/offline-request-owner-state-model`.
- Required starting commit for the next task:
  the pushed `model: add request owner state machine` commit on
  `origin/feature/offline-request-owner-state-model`.
- The repository contains a pure, WDF-independent request-owner state model and
  offline tests. `ChatpadFilter` does not reference or invoke that model.
- The model emits effects for future lifecycle, preparation, formatting,
  send/cancel call pins, terminal retirement, sequence advance/abort, reuse,
  stale completion, and diagnostic fault decisions. It performs no framework
  or device action.

## Recommended next objective

Create the compile-only KMDF request-owner context-definition checkpoint.

The next slice should define the future typed request-owner/context shapes and
compile-time wiring needed to host the pure model behind KMDF-owned storage,
without creating WDF objects, formatting a request, submitting a request,
registering callbacks, or changing runtime behavior.

## Preconditions

1. Start from `origin/feature/offline-request-owner-state-model` at the exact
   pushed `model: add request owner state machine` commit.
2. Confirm the worktree and index are clean.
3. Read, in order:
   - `AGENTS.md`;
   - `docs/PROJECT-STATE.md`;
   - `docs/DECISIONS.md`;
   - this file;
   - the latest `docs/WORKLOG.md` entry;
   - `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
4. Verify `tools\Test-ChatpadRequestOwnerModel.ps1 -Configuration Debug -Platform x64`
   still passes before relying on the model.

## Safety restrictions

- Do not create `WDFREQUEST`, `WDFMEMORY`, `WDFIOTARGET`, queues, timers, work
  items, or USB targets.
- Do not add or register completion, cancel, PnP, power, queue, or timer
  callbacks.
- Do not format, send, cancel, complete, wait for, or reuse a live request.
- Do not call the new context code from `DriverEntry`, `EvtDeviceAdd`,
  D0-entry, D0-exit, cleanup, self-managed I/O, queue, or any runtime path.
- Do not change the INF, catalog/package/signing scripts, staging/install
  paths, registry/service state, Driver Store state, or any hardware/device
  state.
- Keep generated outputs under ignored `artifacts/`.
- Do not modify `legacy/`.

## Acceptance criteria

- Any new KMDF-facing definitions are compile-only, dormant, and guarded by
  tests or wrappers that prove no runtime callback references them.
- The pure model remains WDF-independent and its Debug/Release wrapper runs
  still pass.
- Full solution Debug/Release builds still pass with the WDK-capable MSBuild
  path.
- Existing protocol, transport, lifecycle, control-setup, kernel
  compatibility, WDF formatter, driver build, repository safety, and
  `git diff --check` validations still pass.
- Continuation docs and worklog precisely state that no WDF object or live
  request behavior was created.

## Files and commands to inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git log -5 --oneline --decorate
Get-Content docs\OFFLINE-REQUEST-OWNER-STATE-MODEL.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md
.\tools\Test-ChatpadRequestOwnerModel.ps1 -Configuration Debug -Platform x64
```
