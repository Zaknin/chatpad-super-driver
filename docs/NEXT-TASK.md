# Next Task

## Exact current state

- **Branch:** `feature/kernel-safe-protocol-interface`, tracking
  `origin/feature/kernel-safe-protocol-interface`.
- **Starting point for this checkpoint:**
  `c18b40b2c66ec9c529567ae2df3d01e3a233b6b8`.
- **Checkpoint commit:** the commit named
  `build: add kernel-safe protocol interface check` produced by this task;
  resolve and verify its full hash with `git rev-parse HEAD` before editing.
- `ChatpadProtocolTypes.h` is the portable shared type boundary.
- Direct and integrated user-mode parser tests pass 85/85.
- The isolated WDK compatibility project builds Debug and Release x64 as a
  static library and produces no `.sys`.
- `ChatpadFilter` has no parser or compatibility project reference and links
  neither library. Debug and Release remain unsigned compile-only builds.
- Latest installed KMDF headers/libraries are 1.35; `ChatpadFilter` retains its
  WDK default KMDF target 1.15.

## Next recommended objective

Design a transport-independent parser state machine for initialization and
status classification using synthetic offline fixtures only.

Do not begin semantic key mappings.

## Required branch and starting commit

- Continue on a new task branch based directly on the verified checkpoint
  commit named `build: add kernel-safe protocol interface check`.
- Before editing, record the full starting hash from `git rev-parse HEAD` and
  require a clean working tree.

## Preconditions

- Re-run repository safety and confirm prohibited commit `6502452` is not an
  ancestor of HEAD.
- Re-run the direct parser, integrated Debug/Release tests, and kernel
  compatibility Debug/Release builds.
- Confirm `ChatpadFilter` still has no parser or compatibility dependency.
- Use only synthetic offline fixture data already justified by documented
  evidence; do not request or capture live device data.

## Safety restrictions

- No USB, HID, IOCTL, device callbacks, PnP, power, registry, service,
  transport, keyboard injection, mouse injection, or hardware access.
- Do not install, load, execute, sign, package, deploy, or test a driver.
- Do not modify `legacy/`.
- Keep all generated output beneath ignored `artifacts/`.
- Do not add semantic key mappings.
- Do not link parser or state-machine code into `ChatpadFilter`.

## Acceptance criteria

- A transport-independent state structure and pure parser/classifier API exist.
- Initialization/status inputs are represented only by synthetic offline
  fixtures tied to documented evidence and explicitly label unresolved forms.
- State transitions are deterministic, allocation-free, pointer-retention-free,
  and independently testable in user mode.
- Existing 85 parser assertions remain passing, with focused new offline tests
  for the state machine.
- Kernel compatibility and driver-isolation gates remain passing.

## Inspect first

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/CHATPAD-PROTOCOL.md`
5. `src/protocol/ChatpadProtocol/ChatpadProtocolTypes.h`
6. `src/protocol/ChatpadProtocol/ChatpadKeyboardParser.h`
7. `tests/kernel/ChatpadProtocolKernelCompileCheck/`
8. `tests/protocol/fixtures/`
