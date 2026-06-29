# Next Task

## Exact current state

- **Branch:** `feature/mocked-activation-executor`.
- **Starting checkpoint for the completed task:**
  `e1de1860e2f2ea21146e8de8aeec19892d2c9203`.
- **Activation-executor checkpoint:** commit named
  `feat: add mocked activation executor`; verify its full hash with
  `git rev-parse HEAD` before editing.
- `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h` and `.c` expose
  exactly six confirmed activation request descriptors as caller-owned values.
- `src/protocol/ChatpadProtocol/ChatpadActivationSequence.h` and `.c` expose
  exactly six activation sequence steps as caller-owned values. Step index and
  request index are identical for all six steps, and each step obtains its
  request descriptor from `ChatpadBuildActivationRequest`.
- `src/protocol/ChatpadProtocol/ChatpadActivationExecutor.h` and `.c` expose a
  transport-independent activation execution contract that consumes the planner,
  emits request and nonzero delay metadata callbacks, and records only
  planner/callback outcomes in a caller-provided summary.
- Current successful executor callback order is:
  request 0, delay 0 12 ms, request 1, delay 1 12 ms, request 2, delay 2
  12 ms, request 3, delay 3 12 ms, request 4, delay 4 12 ms, request 5,
  delay 5 12 ms.
- Timing metadata is declarative only:
  `DelayBeforeMilliseconds = 0` for all six steps and
  `DelayAfterMilliseconds = 12` for all six steps. The executor emits nonzero
  delay metadata but never sleeps or enforces time.
- Request/step index 4 is the only descriptor with outbound payload bytes,
  exactly `09 00`.
- No request descriptor, sequence step, executor fixture, or test contains an
  unsupported `90 00` payload.
- Device-to-host requests represent only the expected data-stage length; they
  contain no fabricated response bytes.
- Parser, state-machine, activation-request, activation-sequence,
  activation-executor, user-mode Debug/Release, kernel compatibility
  Debug/Release, and driver Debug/Release validation pass.
- `ChatpadFilter` remains unsigned, nonfunctional, and isolated from
  `ChatpadProtocol.lib`, activation-request source, activation-sequence planner
  source, and activation-executor source.

## Next recommended objective

Perform a read-only Windows device/interface inventory for a connected original
Xbox 360 controller and Chatpad.

The inventory should identify device IDs, VID/PID values, compatible IDs,
service/driver bindings, exposed interfaces, and descriptors obtainable
without vendor control requests, replacing drivers, installing software, or
changing device state.

## Required branch and starting commit

- Continue from the pushed `feature/mocked-activation-executor` checkpoint or
  create a new dedicated branch from that exact commit if the next task should
  be isolated.
- Require a clean working tree and record the full starting hash before any
  read-only inventory work.

## Preconditions

1. Read `AGENTS.md` and all continuity documents.
2. Read `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`.
3. Read `docs/CHATPAD-PROTOCOL.md`.
4. Read `src/protocol/ChatpadProtocol/ChatpadActivationExecutor.h`.
5. Re-run repository safety, legacy-diff, prohibited-ancestor, and direct
   protocol tests before editing if documentation changes are expected.

## Safety restrictions

- Keep `legacy/` immutable and do not execute it.
- Read-only inventory only.
- Do not install software, replace drivers, bind drivers, update drivers,
  enable/disable devices, restart devices, write registry state, load or unload
  drivers, send USB/HID/IOCTL/vendor control requests, capture traffic, or
  attempt activation.
- Do not infer initialization success, ready state, acknowledgement, timeout,
  retry, or response semantics from inventory metadata.
- Store any generated command output or logs under ignored `artifacts/`.

## Acceptance criteria

- Inventory commands are explicitly read-only and documented.
- The report lists discovered controller/chatpad device IDs, VID/PID,
  compatible IDs, service/driver bindings, interfaces, and descriptor metadata
  available from Windows without changing state.
- The report distinguishes facts observed on the current machine from protocol
  conclusions.
- No driver/runtime state is changed and no hardware control request is sent.
- Repository safety still passes if docs are updated.

## Inspect first

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. `docs/WORKLOG.md`
6. `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`
7. `docs/CHATPAD-PROTOCOL.md`
8. `src/protocol/ChatpadProtocol/ChatpadActivationExecutor.h`
