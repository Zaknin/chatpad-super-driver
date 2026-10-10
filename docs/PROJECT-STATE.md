# Project State

Updated 2026-10-10 after the post-reboot TASK 8L-C5 probe.

- Branch: `feature/chatpad-usermode-runner`; current tip is a docs-only continuation of implementation baseline `303b29eb9a06e3c30964fa0027baad53fdca44a0`. No code has changed in this continuation.
- Controller parsing remains strict: exactly 20 bytes, header `00 14`, and existing reserved-button validation. Probe/input-pump skip only the currently documented exact known packets.
- Previous focused verification remains: Release CTest 2/2, bridge tests 545/545, input-pump tests 10/10. Runner binary SHA-256: `4C8828946B150C5E490630E0F1EC8F5FB546FF33FABD888CF2D7CC88030D90C4`.
- Windows booted successfully at `2026-10-10T15:22:56Z`. One strict probe at `15:28:22Z` failed with exit 6 after a successful 3-byte read of `01 03 0e` (`invalid_controller_report`); there was no Win32 transfer error and no `1460` on that probe. No runner was launched.
- A later 20-second read-only IF0 monitor captured the known packets `02 03 00`, `03 03 03`, `08 03 00`, then three valid 20-byte `00 14` reports. User reported pressing a button during the monitor, but each captured report showed `buttons=0x0`; no Chatpad reports were captured. This confirms post-boot IF0 can return valid reports, but does not qualify live button input or runtime.
- The physical target is present with service `WINUSB`, INF `oem104.inf`, ProblemCode 0. Its `USBHUB3` root hub, AMD `USBXHCI` host controller, PCI ancestors, and enumerated USB controller/hub inventory report OK. USBHUB3/UCX analytic channels are disabled; USBXHCI Operational is enabled but contains only three records and no useful transition detail. System log shows no Kernel-Power 42/107 S3 pair since the current boot; older S3 events predate this reboot.
- Current read-only snapshot: broker `ChatpadHidMaestroBroker` Running/Automatic; no runner process; no present virtual Xbox; `%LOCALAPPDATA%\ChatpadBridge\logs\session.active.json` remains present from the prior runtime. It has not been deleted; preserve normal zero-rumble recovery.
- C5 remains PARTIAL. No binding, USB power setting, service, registry, diagnostic-channel, or architecture change was made. No reconnect loop, S3 test, or runtime was started in this continuation.
