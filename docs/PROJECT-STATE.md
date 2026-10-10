# Project State

Updated 2026-10-10 during TASK 8L-C5 post-power-cycle qualification.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD for this follow-up was `2efff47bb2869ed09da12ab1536d3cc99f942488`, pushed to `origin`. Expected new HEAD: the commit containing this PacketHex diagnostic and live-state continuity update; verify with `git rev-parse HEAD` after commit.
- `ParseController` remains strict: exactly 20 bytes, header `00 14`, plus existing reserved-button validation. Readiness/input-pump skip only the exact known status packets `01 03 02`, `02 03 00`, `03 03 03`, `08 03 00`. Invalid probe reports now include the complete packet hex; this is diagnostic output only and does not relax classification.
- Follow-up Release build succeeded at ignored path `artifacts/task-8lc5/status-packet-fix/native-bt/Release/`. Focused CTest passed 2/2; `ChatpadBridgeTests` passed 545/545 and controller input pump passed 10/10. Current diagnostic/runner SHA-256: `4C8828946B150C5E490630E0F1EC8F5FB546FF33FABD888CF2D7CC88030D90C4`.
- After the user power-cycled USB, the updated read-only probe skipped `02 03 00`, `03 03 03`, and `08 03 00`, then accepted a valid 20-byte `00 14` report. A normal-user runner is active; stale keyboard release and zero-rumble recovery passed, virtual Xbox was created, and Chatpad key-data was enabled. A guarded slot-0 rumble pulse produced active/inactive broker callback log entries. User confirmation of current buttons/stick, Chatpad, and rumble is pending.
- The prior S3 attempt failed with WinUSB `1460`, followed by 15 unsuccessful reconnect/activation attempts. Post-power-cycle probe now passes, but sleep/resume and subsequent reconnect qualification still remain.
- C5 is incomplete. No driver rebind, PnP removal, `RemoveAllVirtualControllers`, service/registry/trust/boot/power-setting change, or edit under `legacy/` was performed.
