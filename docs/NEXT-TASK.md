# Next Task

## Qualify external normal-Windows prerequisites; do not start C3 automatically

Branch feature/chatpad-winusb-bridge-poc. Start from C2R1 commit "feat: finish normal-Windows C3 prerequisites", the direct child of63902d912468f7a6819fe4f434bddd504d2bf5da. Resolve exact SHA from Git and canonical TASK-8L-C2R1/20261003T190206Z/result-manifest.json, require equality and remote0/0. Preserve research and working fallback branches.

C2R1 is PARTIAL. Offline exclusion, snapshot recovery, signed inbox-only WinUSB package, real HIDMaestro compilation, stage-specific error31 policy and bounded staged runner exist. Comprehensive offline regression passed2029checks; later focused integration regressions add11newdistinct checks for2040final passes and are in test-summary/worklog. No live mutation or physical acceptance occurred.

Current read-only evidence: normal TESTSIGNING=false, HVCI=true, SecureBoot unknown/inaccessible; physical045E:028E absent and ChatpadFilter stopped. Exact Microsoft recovery sources verify, but a compatible current candidate cannot be proved without the target. Pinned HIDMaestro SDK is compiled; main/XUSB runtime packages are absent. The retained development-signed optional Chatpad filter cannot be claimed loadable with TESTSIGNING off.

Next objective:
1. With explicit authorization for runtime installation in a separate task, inspect and qualify the exact pinned HIDMaestro main/XUSB packages under unchanged normal Windows security. Record their signatures, version/source hashes, load status and rollback. Do not install based solely on embedded resources or SDK presence.
2. Have the human physically connect the intended controller. Perform one read-only PnP status/stack/extension/service/candidate capture; do not repair its stack automatically.
3. Refresh readiness records, verify Microsoft recovery sources/candidate and canonical publication access, then rerun PreflightC3. Preserve precise BLOCKED reasons. Do not label C3_READY until prerequisites truly pass.
4. Only a later physically present human explicitly starting Invoke-ChatpadC3.ps1 -Execute may begin the bounded experiment. No token or automatic next-task creation is required.

First inspect AGENTS.md, PROJECT-STATE.md, DECISIONS.md, WORKLOG.md, CHATPAD-WINUSB-BINDING.md, CHATPAD-WINUSB-TRUST.md, CHATPAD-VIRTUAL-XBOX.md and CHATPAD-WINUSB-C3-PROCEDURE.md. Verify archive/sidecar/readback receipts and current Git. Inspect tools/New-ChatpadC3Readiness.ps1, ChatpadBinding.ps1, ChatpadBinding/C3Planning.psm1/C3Execution.psm1 and Invoke-ChatpadC3.ps1.

Read-only commands:

    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -VerifyRestorable
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PlanWinUsbTransition
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PlanRestoreXbox
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PreflightC3 -JsonPath artifacts/task-8lc2r1/preflight-c3.json
    pwsh -NoProfile -File tools/Invoke-ChatpadC3.ps1

Acceptance: independently qualified ordinary-mode runtime, one exact physical target/current candidate, known package hashes and trusted WinUSB INF/CAT, copied recovery sources, rendered exact mutation/recovery plans, read-only preflight PASS, and fresh canonical publication access evidence. Actual bridge acceptance is a separate C3 result. No security/BCD/trust/power/reboot mutation, unrelated OEM removal or stable/legacy source edit is authorized by this continuation document.