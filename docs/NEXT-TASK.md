# Next Task

## Exact current state

- **Branch:** `feature/activation-sequence-planner`, tracking its same-named
  origin branch after the current task is pushed.
- **Starting checkpoint for this completed task:**
  `095772352def48a6764edd11e795745096e165dc`.
- **Activation-sequence checkpoint:** commit named
  `feat: add activation sequence planner`; verify its full hash with
  `git rev-parse HEAD` before editing.
- `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h` and `.c` expose
  exactly six confirmed activation request descriptors as caller-owned values.
- `src/protocol/ChatpadProtocol/ChatpadActivationSequence.h` and `.c` expose
  exactly six activation sequence steps as caller-owned values. Step index and
  request index are identical for all six steps.
- Each sequence step obtains its request descriptor from
  `ChatpadBuildActivationRequest`; the planner does not duplicate a mutable
  request table.
- Timing metadata is declarative only:
  `DelayBeforeMilliseconds = 0` for all six steps and
  `DelayAfterMilliseconds = 12` for all six steps. The after-delay is only the
  confirmed legacy post-`SendControlRequest` sleep metadata. The zero
  before-delay means no confirmed pre-request delay metadata, not a proven
  no-delay requirement.
- Request/step index 4 is the only descriptor with outbound payload bytes,
  exactly `09 00`.
- No request descriptor, sequence step, fixture, or test contains an
  unsupported `90 00` payload.
- Device-to-host requests represent only the expected data-stage length; they
  contain no fabricated response bytes.
- Parser, state-machine, activation-request, activation-sequence,
  user-mode Debug/Release, kernel compatibility Debug/Release, and driver
  Debug/Release validation pass.
- `ChatpadFilter` remains unsigned, nonfunctional, and isolated from
  `ChatpadProtocol.lib`, activation-request source, and activation-sequence
  planner source.

## Next recommended objective

Create a mocked activation executor that consumes the six-step planner and
validates ordering and timing metadata propagation without USB, sleeps,
retries, response interpretation, driver integration, or hardware access.

## Required branch and starting commit

- Create a dedicated feature branch from the verified commit named
  `feat: add activation sequence planner`.
- Require a clean working tree and record the full starting hash.

## Preconditions

1. Read `AGENTS.md` and all continuity documents.
2. Read `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`, especially sections 7, 8, 9,
   15, 17, and 18.
3. Read `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h` and `.c`.
4. Read `src/protocol/ChatpadProtocol/ChatpadActivationSequence.h` and `.c`.
5. Re-run repository safety, legacy-diff, prohibited-ancestor, and direct
   protocol tests before editing.

## Safety restrictions

- Keep `legacy/` immutable and do not execute it.
- Offline data modeling and tests only.
- No USB, HID, IOCTL, device enumeration, transport, driver integration,
  callbacks, installation, loading, signing, packaging, deployment, capture,
  hardware access, or elevation.
- Do not add executable sleeps, timers, retries, acknowledgement parsing,
  response decoding, ready states, semantic key mappings, or names that claim
  unresolved protocol semantics.
- Do not encode the unused `90 00` comment as a request, response, status, or
  timing marker.

## Acceptance criteria

- The mocked executor consumes planner output without sending requests or
  touching driver/runtime paths.
- Tests prove the executor observes all six steps in order, carries the
  caller-owned request descriptors by value, and records timing metadata
  without sleeping or enforcing time.
- The executor does not introduce response, acknowledgement, readiness, retry,
  timeout, hardware, USB, HID, IOCTL, or driver statuses.
- Existing 443 protocol assertions still pass or are increased with focused
  executor assertions.
- Debug/Release user-mode, Debug/Release kernel compatibility, and
  Debug/Release driver regressions remain passing.
- `ChatpadFilter` remains isolated from the protocol library and activation
  sources.

## Inspect first

1. `AGENTS.md`
2. `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`
3. `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h`
4. `src/protocol/ChatpadProtocol/ChatpadActivationRequests.c`
5. `src/protocol/ChatpadProtocol/ChatpadActivationSequence.h`
6. `src/protocol/ChatpadProtocol/ChatpadActivationSequence.c`
7. `tests/protocol/ChatpadActivationSequenceTests.c`
8. `tests/protocol/fixtures/ChatpadActivationSequenceFixtures.h`
