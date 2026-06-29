# Next Task

## Exact current state

- **Branch:** `analysis/init-status-evidence`, tracking its same-named origin
  branch.
- **Starting checkpoint:** `55a1af2c1418a95fcda51038c1b299cb5a75b91f`.
- **Audit checkpoint:** commit named
  `docs: audit chatpad initialization status evidence`; verify its full hash
  with `git rev-parse HEAD` before editing.
- `docs/CHATPAD-INIT-STATUS-EVIDENCE.md` is the authoritative focused audit.
- `0x90 0x00` is only a tentative comment on an unused internal structure.
- The executable activation path confirms six USB setup tuples and exactly one
  outgoing payload, `09 00`.
- No response form, acknowledgement, ready state, retry policy, `f0` meaning,
  or keepalive/status packet format is confirmed.
- No implementation, runtime, hardware, or build-project change was made.

## Next recommended objective

Add a transport-independent, neutral declarative representation of only the
six confirmed activation control requests and offline tests for exact setup
field construction, direction, data-stage length, and the `09 00` payload.

Do not call the representation a successful initialization sequence and do not
implement response parsing because the audit proves neither semantic boundary.

## Required branch and starting commit

- Create a dedicated feature branch from the verified audit commit named
  `docs: audit chatpad initialization status evidence`.
- Require a clean working tree and record the full starting hash.

## Preconditions

1. Read `AGENTS.md` and all continuity documents.
2. Read `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`, especially sections 7, 8, 15,
   17, and 18.
3. Re-run repository safety, legacy-diff, and prohibited-ancestor checks.
4. Inspect the current protocol library and tests before choosing the neutral
   API shape.

## Safety restrictions

- Keep `legacy/` immutable and do not execute it.
- Offline data modeling and tests only.
- No USB, HID, IOCTL, device enumeration, transport, driver integration,
  callbacks, installation, loading, signing, packaging, deployment, capture,
  or hardware access.
- Do not add retries, timers, keepalive policy, response decoding, ready states,
  semantic key mappings, or names that claim unresolved protocol semantics.
- Do not encode the unused `90 00` comment as a request.

## Acceptance criteria

- Exactly six audited activation setup tuples are represented without extra
  requests or inferred meanings.
- Only the audited host-to-device request carries payload `09 00`; the first
  three requests have no data stage; both device-to-host requests request two
  bytes but do not prescribe response content.
- Tests verify `bmRequestType`, `bRequest`, little-endian `wValue`, `wIndex`,
  `wLength`, direction, and payload length for every tuple.
- The representation has no transport, device, Windows, WDK, USB, or runtime
  dependency and is not integrated into `ChatpadFilter`.
- Existing parser/state-machine tests and applicable compile-only checks pass.

## Inspect first

1. `AGENTS.md`
2. `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`
3. `docs/CHATPAD-PROTOCOL.md`
4. `docs/DECISIONS.md`
5. `src/protocol/ChatpadProtocol/`
6. `tests/protocol/`
