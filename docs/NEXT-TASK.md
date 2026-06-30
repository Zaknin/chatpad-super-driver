# Next Task

## Current continuation point

Branch `feature/offline-driver-activation-plan-integration` contains the first
dormant production-driver activation preparation seam. It compiles the existing
authoritative activation sequence, pure translation, and WDF setup formatter
into `ChatpadFilter` and retains `ChatpadPrepareActivationStep` without calling
it from any runtime callback.

See
[Offline Driver Activation-Plan Integration](OFFLINE-DRIVER-ACTIVATION-PLAN-INTEGRATION.md)
for exact architecture, validation, hashes, and proof boundaries.

## Recommended next objective

Conduct a design-only request-owner and buffer-lifetime checkpoint for a future
per-device KMDF bridge. Define ownership, parenting, generation binding,
failure cleanup, cancellation, completion-once behavior, and transfer-buffer
lifetime without creating a WDF object or adding runtime code.

This file recommends that bounded design task only. It does not authorize
request creation, target discovery, formatting, submission, completion
callbacks, driver loading, installation, or hardware access.

## Required branch and starting commit

- Obtain the exact final integration commit from the external reviewed handoff
  or verify it from synchronized
  `origin/feature/offline-driver-activation-plan-integration`.
- Require local HEAD to equal that specified commit and its upstream.
- Require a clean tracked tree and index.
- Require final commit parent
  `fad671d5d1ede2eda6f0a5defb0b0495c80cc39e`.
- Require prohibited commit `6502452` not to be an ancestor.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, this file, the milestone report,
  and `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`.
- Verify the preparation module remains dormant and runtime callbacks remain
  unchanged.
- Verify Debug/Release build and test evidence required by the future task is
  present or regenerate it only when explicitly authorized.

## Safety restrictions

- Design and offline inspection only.
- No WDF device, target, request, memory, queue, timer, work item, wait object,
  completion callback, or cancellation callback may be created.
- No request may be formatted against a target or submitted.
- No signing, certificate, staging, Driver Store, registry, service,
  installation, driver loading, PnP/device query, USB/Chatpad operation, or
  Windows mutation.
- No generated package, CAT, SYS, certificate, key, binary, or log may be
  tracked.
- Do not modify `legacy/` or retained evidence.

## Acceptance criteria

- Ownership and lifetime rules cover every future success, failure,
  cancellation, stale-generation, duplicate-completion, D0-exit, and removal
  path.
- The design maps one future request record to one lifecycle admission and one
  release without using a raw request pointer as a token.
- No production/runtime source or executable WDF path is added.
- All current integration, test, safety, and containment boundaries remain
  explicit.

## Inspect first

- `src/driver/ChatpadFilter/ChatpadActivationPreparation.h`
- `src/driver/ChatpadFilter/ChatpadActivationPreparation.c`
- `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`
- `docs/OFFLINE-DRIVER-ACTIVATION-PLAN-INTEGRATION.md`
- `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`
- `src/driver/ChatpadFilter/ChatpadFilterLifecycle.h`
- `src/transport/ChatpadTransport/ChatpadTransportAdapter.h`
