# Next Task

## Current continuation point

Branch `feature/control-setup-translation` contains the pure caller-owned
control-setup translator, native `141/141` Debug/Release tests, source/project
guard, solution integration, and WDK kernel compile coverage. The task commit
subject is `feat: add pure control setup translation`; use the final commit
reported for this task and verify it equals
`origin/feature/control-setup-translation` before branching.

## Recommended objective

Create an isolated compile-only WDK formatter library that converts a validated
`ChatpadControlSetupTranslation` value into an inspectable
`WDF_USB_CONTROL_SETUP_PACKET` value. This task may prove type/field formatting
only. Do not connect it to `ChatpadFilter` and do not create, format, allocate,
submit, cancel, or complete any WDF request.

## Required branch and starting commit

- Create a dedicated next-task branch from the final
  `feature/control-setup-translation` commit reported and pushed by this task.
- Require exact equality between local starting commit and the reported
  `origin/feature/control-setup-translation` commit, with a clean tree.
- Require prohibited commit `6502452` not to be an ancestor.

## Preconditions

- Re-read `AGENTS.md`, continuity documents, both Windows 11 architecture
  documents, `docs/CHATPAD-PROTOCOL.md`, and `docs/BUILDING.md`.
- Re-run repository safety plus protocol `610/610`, transport `186/186`,
  lifecycle `109/109`, and control-setup `141/141` baselines.
- Inspect `ChatpadControlSetup`, its tests/guard, kernel compile check, and the
  current `ChatpadFilter` project/source isolation.

## Safety restrictions

- Compile-only isolated static library; output `.lib` only beneath `artifacts/`.
- No WDFDEVICE, WDFIOTARGET, WDFREQUEST, memory object, queue, interface,
  timer, work item, thread, target creation, request formatting/submission,
  completion, cancellation, response buffer, USB/HID/IOCTL/URB/device access,
  endpoint/pipe behavior, INF/CAT/certificate/package/service/installer,
  signing, installation, deployment, loading, capture, elevation, or hardware
  action.
- No `ChatpadFilter` source/project/solution dependency and no `legacy/` edit.

## Acceptance criteria

- Exact setup bytes and direction remain unchanged from the pure translator.
- WDF setup value fields are inspectable in compile-only tests without a target
  or request.
- Debug and Release WDK builds emit only a static library, with no signing or
  package output.
- Existing assertion counts and unsigned driver builds remain unchanged.
- Documentation states that formatting proves neither default-control access
  nor transmission, acceptance, acknowledgement, or readiness.

## Inspect first

- `src/transport/ChatpadControlSetup/ChatpadControlSetup.h`
- `src/transport/ChatpadControlSetup/ChatpadControlSetup.c`
- `tests/transport/ChatpadControlSetupTests/`
- `tools/Test-ChatpadControlSetup.ps1`
- `tests/kernel/ChatpadProtocolKernelCompileCheck/`
- `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`
- `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`
