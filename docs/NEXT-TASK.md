# Next Task

## Exact current state

- **Branch:** `feature/activation-request-builder`, tracking its same-named
  origin branch.
- **Starting checkpoint:** `782e8e15037af1ec524b69ee38003977d3b99fa5`.
- **Activation-builder checkpoint:** commit named
  `feat: add declarative activation request builder`; verify its full hash
  with `git rev-parse HEAD` before editing.
- `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h` and `.c` expose
  exactly six confirmed activation request descriptors as caller-owned values.
- Request index 4 is the only descriptor with outbound payload bytes, exactly
  `09 00`.
- No request descriptor contains or tests an unsupported `90 00` payload.
- Device-to-host requests represent only the expected data-stage length; they
  contain no fabricated response bytes.
- The builder is offline and transport-independent. It performs no I/O,
  allocation, USB/HID/IOCTL/device access, sleeping, retrying, acknowledgement
  handling, ready-state transition, or response decoding.
- Parser, state-machine, activation-request, user-mode Debug/Release, kernel
  compatibility Debug/Release, and driver Debug/Release validation pass.
- `ChatpadFilter` remains unsigned, nonfunctional, and isolated from
  `ChatpadProtocol.lib` and the activation-request source.

## Next recommended objective

Create a transport-independent activation-sequence planner that exposes the
six confirmed activation request descriptors in order and represents the
confirmed legacy inter-request timing as metadata only.

The planner must not sleep, retry, send USB requests, access hardware, decode
responses, interpret acknowledgements, claim readiness, or integrate with the
driver.

## Required branch and starting commit

- Create a dedicated feature branch from the verified activation-builder
  commit named `feat: add declarative activation request builder`.
- Require a clean working tree and record the full starting hash.

## Preconditions

1. Read `AGENTS.md` and all continuity documents.
2. Read `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`, especially sections 7, 8, 9,
   15, 17, and 18.
3. Read `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h` and `.c`.
4. Re-run repository safety, legacy-diff, and prohibited-ancestor checks.
5. Run the direct protocol test once before editing.

## Safety restrictions

- Keep `legacy/` immutable and do not execute it.
- Offline data modeling and tests only.
- No USB, HID, IOCTL, device enumeration, transport, driver integration,
  callbacks, installation, loading, signing, packaging, deployment, capture,
  hardware access, or elevation.
- Do not add sleeps, timers that execute, retries, acknowledgement parsing,
  response decoding, ready states, semantic key mappings, or names that claim
  unresolved protocol semantics.
- Do not encode the unused `90 00` comment as a request or timing marker.

## Acceptance criteria

- The planner exposes the existing six descriptors in order without duplicating
  or changing setup fields or payload bytes.
- Any timing representation is metadata only and derives from documented
  legacy evidence; it does not perform waiting or enforce runtime policy.
- Tests prove order, metadata values, no mutation of returned descriptors, no
  retained caller pointers, and no transport/result statuses beyond API
  validation.
- Existing 300 protocol assertions still pass.
- Debug/Release user-mode, Debug/Release kernel compatibility, and
  Debug/Release driver regressions remain passing.
- `ChatpadFilter` remains isolated from the protocol library and activation
  planner.

## Inspect first

1. `AGENTS.md`
2. `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`
3. `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h`
4. `src/protocol/ChatpadProtocol/ChatpadActivationRequests.c`
5. `tests/protocol/ChatpadActivationRequestsTests.c`
6. `tests/protocol/fixtures/ChatpadActivationRequestFixtures.h`
