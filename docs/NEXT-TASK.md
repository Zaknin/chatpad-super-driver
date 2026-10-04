# Next Task

Recommended objective: finish TASK 8L-C4 live qualification for the packaged user-mode runner. Do not start automatically.

Current state: C4 implementation/package PASS and repository regression PASS; live acceptance PARTIAL. The runner is built and waits safely while the device remains on Microsoft `xusb22`. This session was not elevated, so setup stopped before any mutation. No live device or virtual-controller exercise was performed.

Required branch: `feature/chatpad-usermode-runner`, starting from its current clean, pushed C4 closeout commit. Confirm exact HEAD and remote state before work.

First inspect: `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`, then C4 result manifest/receipt and ignored `artifacts/task-8lc4` evidence. Reconcile Git and hardware state before acting.

Preconditions: elevated PowerShell for one-time `ChatpadSetup.ps1 -Mode Install`; confirm readiness/package hashes, current exact target, Microsoft recovery source and runtime state. Keep normal `ChatpadBridge.exe run/status` non-elevated if tests show that works.

Safety: preserve the exact Microsoft recovery baseline; do not reinstall obsolete `oem104`, modify `legacy/`, broadly remove HID devices, change signing/security/trust, reboot, stress-test, or change stable driver/protocol code. Stop and restore Microsoft Xbox if exact target/package identity is ambiguous or setup fails. Do not retry blind physical operations.

Acceptance: verify setup bind and recovery; prove normal-user startup without rebinding; controller to XInput, Chatpad to keyboard, low/moderate rumble; restart and unplugged startup; reconnect at least three times; held controller/key/modifier disconnect cleanup; killed-process recovery including virtual-controller stale cleanup; no duplicate virtual nodes; collect compact runtime telemetry and idle resource sample. Run the comprehensive suite once after fixes. Publish sanitized evidence atomically and report verified versus untested behavior.

Inspect first: `tools/ChatpadSetup.ps1`, `tools/Build-ChatpadBridge.ps1`, packaged `ChatpadBridge.exe`, `tools/ChatpadWinUsbPoc/Runner.cpp`, and C4 setup/preflight/lifecycle evidence under `artifacts/task-8lc4`.
