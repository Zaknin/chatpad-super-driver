# Next Task

## TASK 8L-C2 — Offline preparation of a bounded WinUSB/UMDF experiment

### Exact current state

- Required branch: `research/chatpad-usermode-transport`.
- Required starting checkpoint: `docs: assess whole-device WinUSB and UMDF bridge`, direct child of `51dbe52d0f926afbcac714fbef7d2cc76dde102a`. Resolve exact SHA with `git log -1 --format=%H` and verify it matches the pushed research branch before work. Do not change feature branches.
- Read AGENTS, PROJECT-STATE, DECISIONS, this file, latest WORKLOG, `CHATPAD-WHOLE-DEVICE-WINUSB-RESEARCH.md` and `CHATPAD-WHOLE-DEVICE-EXPERIMENT.md`.
- C1 final sample: TESTSIGNING/HVCI flags on, problem 0, xusb22/ChatpadFilter/vhf running, exact 1.0.14 installed image, physical XInput slot 0 works. Actual state must be refreshed, not assumed. Seven active interfaces; WinUSB initialization fails 87 under current xusb22. No new raw Chatpad user-mode monitor/bridge exists.
- Existing ChatpadControl status/diagnostics fail 87. Keep this separate from hardware/virtual-backend research; do not silently fix it or claim configuration acceptance.
- Whole-device WinUSB plus standard HIDMaestro UMDF2 is technically supported as a candidate, not locally validated. All ordinary-boot/virtual-backend/physical bridge acceptance remains untested.

### Next objective

Prepare the concrete code/package draft/dry-run needed to make a later live authorization reviewable. Follow experiment section 0 and its exact binding/rollback contract. Use the existing portable protocol implementation; no GPL source copying. Keep native USB transport independent from a small managed HIDMaestro adapter. Do not make installer calls an implicit consequence of normal startup or tests.

### Preconditions and scope

1. Confirm clean/synchronized Git and applicable instructions, existing build tools, exact rollback INF/SYS/CAT hashes, and unchanged reference feature branch.
2. Preserve `artifacts/task-8l/` and `artifacts/task-8lc1/`; generate new outputs only in ignored `artifacts/task-8lc2/`.
3. Pin HIDMaestro v1.10.1 / `1c126ed4780322454391b7be782230b35b0810f6`; only standard `xbox-360-wired`. Confirm managed SDK requirements. Do not install SDKs or driver packages merely to make a build pass; report a missing prerequisite.
4. Treat the old exact-instance restoration entrypoint as non-executing until audited/implemented for this plan. No claimed rollback capability based on a dry-run returning PASS.

### Safety restrictions

No live USB rebind, Chatpad INF removal, virtual backend install/creation, trust-store change, BCD/security/power change, driver build/sign/package/deploy, raw activation/pipe access, SendInput, device restart or reboot. User-mode offline compilation and tests require the next task's implementation scope; this handoff is a recommendation, not permission to execute live phases. No legacy edits, per-game DLL hooks, global filter cleanup or automatic installer invocation. Do not overwrite dirty work.

### Acceptance criteria

- Bounded native monitor supports descriptor/pipe checks, controller packet validation, existing Chatpad activation/keepalive/001B semantics and logging; independently selectable monitor/bridge modes; no hardware access during offline tests.
- Managed helper uses supported SDK with explicit install/create boundaries; native app does not depend on private shared-memory layout. Source/length validation and copying of output callback data, independent trigger handling, neutral/release/cancel and motor-stop behavior covered by focused offline tests.
- Independent system-XInput observer records return codes, identifies the intended virtual slot and fails on timeout/disconnection; no first-connected-slot shortcut or exit-zero-only benchmark assertion.
- Installation/rollback dry-run names exact hardware target and package/certificate/property deltas and enforces single-device/dependency checks. New binding INF remains a draft until signing/package preparation is explicitly authorized; update safety allowlist deliberately if adding a tracked new INF source.
- Full physical-to-XInput/keyboard execution and ordinary-boot qualification remain explicitly untested. Produce a concrete final live action list with rollback artifacts, expected physical XInput loss and finite acceptance windows, then seek the exact missing live authorization only after preparation is complete.
- Inspect full diff, validate repository safety, update continuity, commit together and push only research branch. No production architecture commitment solely from offline tests.

### First commands/files

`git status --short --branch`, `git log -3 --oneline`, read-only fresh PnP/XInput state, the two C1 research documents, `src/protocol/ChatpadProtocol/`, `src/driver/ChatpadFilter/ChatpadLiveRuntime.c`, and ignored `artifacts/task-8lc1/hidmaestro-audit.md` / pinned reference sources. C1 `final-state.json`, `final-stack.txt`, `evidence-check.json` and `repository-safety.txt` describe the last verified sample.
