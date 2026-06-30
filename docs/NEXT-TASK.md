# Next Task

## Current continuation point

Branch `feature/offline-kmdf-request-owner-design` defines the authoritative
future request and buffer ownership model in
[Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md).
It selects one reusable device-parented activation request, a typed request
context, separate request-parented two-byte outbound/inbound memory objects,
and exact send/completion/cancellation/lifecycle race rules.

This checkpoint is documentation only. No WDF object, callback, request,
target, memory, format, send, cancel, delay, USB access, or runtime behavior was
added.

## Recommended next objective

Implement only a pure, WDF-independent request-owner state model and exhaustive
offline unit tests for reservation, preparation, send publication, immediate
completion, cancellation call pinning, exact-once terminal retirement,
generation staleness, draining, and buffer-validity metadata.

This file identifies that bounded future slice; it does not authorize it.
Request context/WDF type definitions, object creation, memory creation,
formatting, submission, cancellation calls, completion callbacks, driver
loading, installation, network access, and hardware interaction remain outside
that slice.

## Required branch and starting commit

- Start from the exact externally reported final commit of
  `feature/offline-kmdf-request-owner-design`.
- Require that commit's parent to be
  `b814822a540f84b93b1a02809fd1bdb0a61ac02d`.
- Require local HEAD and
  `origin/feature/offline-kmdf-request-owner-design` to match with a clean
  tracked tree and index.
- Use a new branch such as `feature/offline-request-owner-state-model` only if
  a later task explicitly authorizes the implementation.
- Do not reset, clean, stash, pull, merge, rebase, amend, or repair a mismatch.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, this file, the authoritative
  request-owner document, and the newest worklog entry.
- Verify the dormant preparation API remains uncalled and runtime callbacks are
  unchanged.
- Translate every binding state, transition, call pin, generation check,
  exact-once marker, and matrix case into a portable model/test requirement
  before editing.
- Keep the existing lifecycle and transport cores authoritative; do not
  duplicate generation or token semantics.

## Safety restrictions

- Offline portable model and tests only, if separately authorized.
- No WDF/WDK header dependency in the portable state model.
- No `WDFDEVICE`, target, request, memory, lock, queue, timer, work item, event,
  thread, completion, cancellation call, formatting, submission, wait, or
  delay execution.
- No production driver callback or project integration.
- No INF, CAT, package, certificate, signing, staging, installation, Driver
  Store, registry, service, driver load, PnP/device query, USB/Chatpad action,
  operating-system mutation, or hardware interaction.
- Do not modify `legacy/` or retained evidence.

## Acceptance criteria

- The pure model has no Windows/WDF dependency and allocates no unbounded
  request records.
- Tests cover every state transition and failure-matrix row in the
  authoritative design, including completion-before-send-return and
  completion-during-cancel-call.
- One successful admission maps to one release in every terminal permutation;
  duplicate/stale observations cannot release current-generation accounting or
  advance sequencing.
- Buffer-validity tests prove capacities remain two bytes and stale success
  data cannot survive a later failure.
- Activation ownership remains separate from continuous input.
- No runtime WDF or hardware capability is claimed or implied.

## Inspect first

- `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`
- `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`
- `src/driver/ChatpadFilter/ChatpadFilterLifecycle.h`
- `src/driver/ChatpadFilter/ChatpadFilterLifecycle.c`
- `src/transport/ChatpadTransport/ChatpadTransportAdapter.h`
- `src/transport/ChatpadTransport/ChatpadTransportAdapter.c`
- `tests/driver/ChatpadFilterLifecycleTests/ChatpadFilterLifecycleTests.c`
- `tests/transport/ChatpadTransportTests.c`
