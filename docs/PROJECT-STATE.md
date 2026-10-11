# Project State

Updated 2026-10-11 after the authorized active controller-pump capture.

- Branch: `feature/chatpad-usermode-runner`. Source and test changes are being closed out from baseline `4b5c0f7ca03e8f9653123f8ddf97e107f5b51298`; see the enclosing commit for the updated HEAD.
- Verified toolchain: Visual Studio 2022 Release build passed for `ChatpadControllerInputPumpTests` and `ChatpadWinUsbPoc`. Focused pump suite passed 15/15 checks and CTest `controller-input-pump` passed 1/1. `git diff --check` passed.
- Controller parsing remains strict: exactly 20 bytes with header `00 14`. Pump diagnostics now report read attempts/completions, all/change reports, status/invalid packets, timeouts including Win32 1460, and transfer failures. No parsing or runtime behavior was relaxed.
- Authorized non-elevated PTY run `2026-10-11T07:10:38.722Z`–`07:11:09.821Z` reached RUNNING, created the virtual Xbox, enabled Chatpad key-data, and received active button/stick input during the prompted window. Counts: total controller reports 1,435 (readiness 1, pump 1,434), changing pump reports 1,433, Chatpad reports 56, virtual submissions 1,450; pump attempts 1,528, successful reads 1,434, timeouts 94 (all Win32 1460), status/invalid/other transfer failures 0. Clean shutdown: keys released, virtual neutral/released, motors stopped.
- The earlier low-count production run (`controllerPumpReports=1`) remains unexplained, but the discrepancy was not reproduced in the active run above. A separate run with no user actuation was classified as idle baseline. A later attempt before this successful run lost the device during activation four times; after the user woke the controller, the subsequent run reached RUNNING. This correlation does not establish the root cause.
- Latest read-only state: broker Running/Automatic; physical `USB\VID_045E&PID_028E\1C21F10` Status OK, WINUSB, ProblemCode 0; no bridge process, virtual controller, or active session marker.
- C5 remains PARTIAL because recovery after Windows S3 sleep has not been successfully qualified. No sleep/reboot, driver binding, USB power, PnP, service, or unrelated HIDMaestro changes were made in this diagnostic step.
