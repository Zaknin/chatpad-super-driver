# Next Task

## Exact current state

- **Branch:** `feature/offline-protocol-state-machine`, tracking its same-named
  origin branch.
- **Checkpoint parent:** `804393c9c9e1c0b976c0ad73f6f1fcc5c57de5c2`.
- **Checkpoint commit:** the commit named
  `feat: add offline protocol state machine`; verify its full hash with
  `git rev-parse HEAD` before editing.
- Parser and offline state-machine tests pass 174/174 directly and in Debug and
  Release x64.
- Parser and state-machine sources compile through the isolated WDK project in
  Debug and Release.
- `ChatpadFilter` remains isolated, unsigned, and nonfunctional.
- Initialization/status wire decoding remains unresolved. The current
  unresolved control/status event is explicitly a caller abstraction.

## Next recommended objective

Perform a read-only, offline legacy-source evidence audit focused narrowly on
initialization and status paths, especially the provenance and use of the
`0x90, 0x00` structure bytes.

Do not implement new state-machine classifications unless the audit finds
direct, traceable evidence supporting them.

## Required branch and starting commit

- Create a dedicated audit branch directly from the verified checkpoint commit
  named `feat: add offline protocol state machine`.
- Record the full starting hash and require a clean tree before analysis.

## Preconditions

- Re-run repository safety and prohibited-ancestor checks.
- Re-run direct tests and Debug/Release kernel compatibility checks.
- Treat `docs/CHATPAD-PROTOCOL.md` and immutable `legacy/` source as the only
  evidence inputs.

## Safety restrictions

- Read-only protocol evidence analysis; do not modify `legacy/`.
- No hardware, USB, HID, IOCTL execution, device callbacks, transport access,
  driver runtime changes, installation, loading, signing, packaging, or
  deployment.
- Do not infer ready, initialized, connected, online, or authenticated states.
- Do not add semantic key mappings.
- Keep any generated analysis output beneath ignored `artifacts/`.

## Acceptance criteria

- Every initialization/status claim is tied to exact immutable source evidence.
- Internal structures, abstract events, and confirmed wire forms remain
  structurally separated.
- Conflicts and unresolved meanings are stated without speculative decoding.
- `docs/CHATPAD-PROTOCOL.md` changes only if the audit establishes a real
  clarification or correction.
- No runtime or build integration changes are made.

## Inspect first

1. `AGENTS.md`
2. `docs/CHATPAD-PROTOCOL.md`
3. `docs/DECISIONS.md`
4. `src/protocol/ChatpadProtocol/ChatpadProtocolStateMachine.h`
5. `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h`
6. Initialization/status references under `legacy/source_release_0_0_4a/`
