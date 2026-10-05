# TASK 8L-C4L2 — Validate startup controller polling fix

## Current state

- Branch: `feature/chatpad-usermode-runner`; package implementation/build commit `a6b304f1da41de83908f75aebfb32d9533ee728b`. Current change after build is limited to `docs/PROJECT-STATE.md`, `docs/WORKLOG.md`, and this file; publisher will regenerate readiness for the resulting pushed commit.
- Fresh package: `artifacts/task-8lc4l2/build-startup-input-poll-a6b304f/package`; manifest has 214 members and runner SHA-256 `5E26662C53FD5899B1AFFFD7E09E1DDA6E3C869861567F91423B0BEF66985687`.
- Verification PASS: managed helper 504/504 across three runs; focused CTest 3/3; setup and readiness checks PASS; package inventory exact. Prepared immutable release `20261005T035300Z`, archive SHA-256 `23BA57F588630F61D811F1A33F75A0FAA57BCAED35DFF73608CD4B66D17E0695`.
- The user already repaired the broker successfully. Its helper payload is unchanged; do not request another elevated repair for this runner-only correction.
- Source diagnosis remains a hypothesis until normal-user hardware retry confirms the initial zero-rumble write now succeeds.

## Next steps

1. Commit/push only the docs-only package-preparation update on `feature/chatpad-usermode-runner`.
2. Run `tools/Publish-ChatpadC4L2.ps1 -Mode Publish -UtcTimestamp 20261005T035300Z -BuildDirectory artifacts/task-8lc4l2/build-startup-input-poll-a6b304f -VerificationSummaryPath artifacts/task-8lc4l2/build-startup-input-poll-a6b304f/release-verification.json`.
3. Independently verify canonical payload SHA-256 sidecars, no `.part`, final completion receipt, and readiness release identity.
4. Give the user the package's exact normal-user command `& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-startup-input-poll-a6b304f\package\ChatpadBridge.exe" run` and wait for the complete log.

## Safety and acceptance

- Do not perform service lifecycle changes, driver binding, PnP/registry mutation, trust changes, reboot, elevated bridge execution, or HIDMaestro global cleanup.
- Keep initial zero-rumble and exact XUSB interface validation strict. Confirm startup polling event, successful zero-rumble write, and virtual controller creation from the user's log. Then separately resume XInput and physical rumble qualification.
- Inspect first: `Runner.cpp`, `ControllerInputPump.{h,cpp}`, `controller-input-pump-tests.cpp`, and the package/publisher verification records.
