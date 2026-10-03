# Next Task

## TASK 8L-C1 - Comparative interface census on a healthy Xbox stack

### Exact starting state

- Required branch: `research/chatpad-usermode-transport`.
- Required starting commit: the pushed checkpoint `docs: record user-mode Chatpad transport research`, direct child of `4759f7f01fe03edd96b66bb75f5c14d732b36016`. Resolve exact SHA with `git log -1 --format=%H` and compare upstream before work. Do not alter feature branches.
- Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`, and `docs/CHATPAD-USERMODE-TRANSPORT-RESEARCH.md`.
- Current normal boot: oem104.inf 1.0.14 selected, Code 52 / 0xC0000428, xusb22/ChatpadFilter/vhf stopped, USBHUB3-only actual stack. User confirmed this and offered a comparative reboot if necessary; no reboot was performed or scheduled.
- Native hub queries already proved four interfaces and Chatpad interface 2 / endpoint 84. No MI child PDO or accessible Chatpad stream exists in this failed boot. No functional user-mode POC exists.

### Objective and preconditions

Compare registered interfaces, shared handle access, HID capabilities and known read-only queries once the controller stack is healthy. Close the healthy-stack evidence gap without mistaking our filter's services for a driverless transport.

1. Preserve the ignored `artifacts/task-8l/` normal-boot baseline before reusing its probe, which overwrites output files. Re-resolve physical parent and connection index after any port/boot change; the original script uses port 6.
2. Inspect current PnP service, actual stack, extension/filter bindings, problem status and XInput connection state before any API conclusion.
3. An operator-controlled return to the previously working development boot can provide a useful interface comparison. If our filter loads there, classify it as a custom-driver baseline, never pure user mode.
4. The decisive driverless sample requires healthy Microsoft xusb22 with no custom filter in the actual stack. If this requires extension removal, present the exact technical reason, package/device scope, expected Xbox effect, verified rollback command/package and reboot requirements before requesting/performing that mutation. Current TASK 8L does not authorize removing oem104.inf, changing filters, or installing anything.

### Safety restrictions

- Keep ordinary controller operation intact if healthy. No arbitrary IOCTL scan, concurrent raw controller endpoint reader, device reset, package deletion, new installation, WinUSB/Zadig/libusbK/UsbDk binding or registry changes.
- Do not change test signing, Secure Boot, HVCI, VBS, selective suspend or power policy. An offered reboot does not authorize changing those settings.
- Do not execute the superseded TASK 8K-T1 installation instructions. Do not load/build/sign/package a driver as part of interface research.
- No legacy/source refactor, VHF experiment or fake SendInput demonstration.

### Acceptance criteria

- Precisely label every sample's actual stack and normal Xbox/XInput health.
- Enumerate every associated published interface with Configuration Manager/SetupAPI; record GUID, exact local symbolic link, access/share flags and measured errors. Keep machine-specific raw identities in ignored artifacts.
- On openable HID handles query capabilities using documented non-mutating APIs; on XUSB use only source-identified non-mutating operations. Record unavailable operations as untested, not denied.
- Distinguish physical interface 2 / endpoint 84 from a bindable PnP child and an accessible user handle.
- Only if a real legitimate transport without the custom filter exists: implement minimal monitor, acquire genuine five-byte reports, then consider mapper + SendInput. Otherwise document the supported-path limit and qualified architecture verdict.
- Commit research/continuity updates together on this branch, push only this branch, leave clean/synchronized.

### First commands/files

`git status --short --branch`, `git log -2 --oneline`, read-only `Get-PnpDevice` and `pnputil /enum-devices /instanceid <fresh-target-id> /relations /services /stack /drivers /interfaces /properties`.

Local ignored scripts: `artifacts/task-8l/Inspect.ps1`, `UsbResearch.cs`, `UsbResearchExactString.cs`, `Additional.ps1`. They are diagnostic probes, not product code or a functional POC. Exact prior outputs are in `pnp-stack.txt`, `interface-opens.json`, `hub-descriptors.json`, `known-interface-counts.json` and `xinput.json`.
