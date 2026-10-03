# Bounded whole-device WinUSB binding preparation

TASK 8L-C2 prepares source, an unsigned package, read-only baseline capture and a gated exact-instance function selector. **The current device cannot safely be switched with this tool yet.** The installed Chatpad extension/filter exclusion is unresolved; the generated catalog is unsigned. No binding/install/sign/trust/restart operation was performed. This is a preparation result with a bounded live-experiment blocker.

## Package contract and trust

`tools/ChatpadBinding/ChatpadWholeDeviceWinUSB.inf` has one AMD64 Windows 11 model: `USB\VID_045E&PID_028E`. Its application GUID is `{B6A5D05E-7E18-4DF1-8E47-12F072DE2C36}`, shared with the POC. It uses `Include=winusb.inf`, `Needs=WINUSB.NT` and `WINUSB.NT.Services`, plus the device-interface registration. There is no custom SYS, coinstaller, filter registration or MI child match. This supersedes the draft GUID in the historical C1 experiment document.

Run `pwsh -NoProfile -File tools/ChatpadBinding/Build-Package.ps1` to copy the source into ignored `artifacts/task-8lc2/binding/package/`, validate it with WDK 10.0.26100.0 InfVerif `/u`, and generate an **unsigned** catalog with Inf2Cat `/os:10_CO_X64 /uselocaltime`. C2 succeeded with zero Inf2Cat errors/warnings. Package generation does not stage or install the package. [Microsoft's catalog-generation instructions](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/creating-a-catalog-file-for-a-pnp-driver-package).

The Microsoft signature on inbox `winusb.sys` does not sign our INF. Windows requires the exact INF/catalog package to have a trusted signature before staging/installing it. Changing the INF invalidates catalog membership. A local test signer requires its chain in LocalMachine Trusted Root Certification Authorities and its publisher certificate in LocalMachine Trusted Publishers; those changes require separate explicit authorization. No signing, certificate generation, import, or trust-store change is included here. A public release requires a release-signing policy. The ordinary-boot Windows 11 install/load result, with TESTSIGNING off and unchanged Secure Boot/HVCI, remains **UNTESTED**; local trust is a package requirement, not empirical proof of that boot's acceptance. [WinUSB installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation), [Driver Store trust](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/driver-store), [test-certificate stores](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/installing-a-test-certificate-on-a-test-computer).

## Read-only commands and baseline

```powershell
pwsh -NoProfile -File tools/ChatpadBinding.ps1 -Status
pwsh -NoProfile -File tools/ChatpadBinding.ps1 -CaptureBaseline -OutputDirectory artifacts/task-8lc2/binding/new-baseline
pwsh -NoProfile -File tools/ChatpadBinding.ps1 -Verify -ExpectedState Xbox -BaselinePath artifacts/task-8lc2/binding/baseline-verified/baseline.json
pwsh -NoProfile -File tools/Test-ChatpadBinding.ps1
```

Status enumerates present physical instances only, then reports hardware/container identity, base INF/provider/model/version/service/problem, device and class filters, raw PnP actual stack, candidate packages, interfaces and service-image locations. Multiple physical matches require an exact `-InstanceId`; an MI or IG child never qualifies. These read-only queries and package-file copying succeeded without elevation in C2. Status contains private instance/container paths and remains local under artifacts.

The verified capture is `artifacts/task-8lc2/binding/baseline-verified/baseline.json`. It records **base** `xusb22.inf` 10.0.26100.9278 / `CC_Install` / Microsoft, the separate installed extension identity, healthy problem 0 and ordered `vhf,ChatpadFilter` lower filters. Seven files are independently copied/hash checked: inbox INF/catalog, extension INF/CAT/SYS, xusb22 image and VHF image. The installed Chatpad service image is read from its actual DriverStore path. The JSON's SHA-256 must be recorded independently for any later execution. The capture copies installed package material; it performs no package export/staging and cannot recreate trust/security policy. Initial partial captures are retained under artifacts and are superseded by `baseline-verified`.

## Plans and future execution gate

```powershell
# C2-safe: plans only. Bind exits 2 for the present blockers; restore plan exits 0.
pwsh -NoProfile -File tools/ChatpadBinding.ps1 -BindWinUsb -BaselinePath artifacts/task-8lc2/binding/baseline-verified/baseline.json
pwsh -NoProfile -File tools/ChatpadBinding.ps1 -RestoreXbox -BaselinePath artifacts/task-8lc2/binding/baseline-verified/baseline.json
```

Mutation requires all of: a separately authorized future live task, explicit `-Execute`, exact authorization marker `TASK-8L-C3-EXACT-DEVICE-BINDING`, an independently recorded `-BaselineSha256`, elevation, live data rather than fixtures, intact captured files and installed extension/image hashes, exact instance/container/hardware identity, reviewed package/model/provider/version, and no plan blockers. Supplying a marker does not grant human authorization. The script re-queries immediately before the native call. It never installs implicitly in Status, CaptureBaseline, Verify, plan mode or automated tests.

`ExactDevice.cs` opens only the recorded instance, verifies its returned ID, builds a compatible list constrained to one absolute INF through `DI_ENUMSINGLEINF`, and selects exactly one driver node matching INF, section, provider, version **and exact model hardware ID**. The inbox INF has both exact VID/PID and `USB\MS_COMP_XUSB10` nodes; the latter is intentionally excluded. The exact inbox candidate was verified through `InspectCandidate` without invoking selected-driver/install APIs. Actual execution uses `SetupDiSetSelectedDriverW` and `DiInstallDevice(flags=0)` on the retained device element. No global hardware-ID update, package deletion, service deletion, restart or reboot exists in the tool. `NeedReboot` stops with exit 5. [DiInstallDevice](https://learn.microsoft.com/en-us/windows/win32/api/newdev/nf-newdev-diinstalldevice).

Restore does not need the POC process or a WinUSB handle. It selects the captured Microsoft node even if the target is in a problem state. It requires the original package/image and unchanged extension/device/class filters. Filter drift or missing extension is a **blocked recovery dependency**, not successful rollback: this binding-only selector does not recreate removed extensions or write filter properties. Live execution and real Xbox input restoration remain **UNTESTED**. A successful native bind alone is not full physical rollback acceptance.

Verify recognizes healthy Xbox or clean WinUSB ownership. WinUSB requires our exact model/provider/version, application interface GUID and no device/class/actual-stack filter contamination. With an Xbox baseline it additionally checks identity, version, filter order and installed image hash. It does not prove XInput motion, raw WinUSB I/O, keyboard input or normal-boot policy.

| Exit | Meaning |
|---|---|
| 0 | Read-only operation/plan succeeded, or requested binding predicates met |
| 2 | Verification mismatch or plan blocked; no mutation attempted |
| 3 | Invalid input, failed authorization/precondition or failed query |
| 4 | Native operation/postcondition failed; preserve evidence and stop |
| 5 | Native operation requested reboot; operator action required |

## Why current WinUSB binding stops

The immutable extension's exact VID/PID model registers ordered lower filters through append `AddReg`. Microsoft documents that extension settings apply after the base INF and remain applicable after base-driver replacement. Clearing a device property before selecting WinUSB cannot safely establish exclusion: PnP may reapply the extension during installation. The new base INF cannot reliably override it. [Extension/base-driver behavior](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/using-an-extension-inf-file).

No reviewed documented per-instance extension-suppression mechanism was established in C2. The tool therefore refuses WinUSB while any Chatpad extension or device/class filter remains. It contains no `oem104.inf` removal, class-filter edit, service deletion or speculative filter clearing. C3 must first resolve per-instance exclusion and exact filter restoration, or explicitly authorize and review a dependency-proven package removal/reinstallation procedure outside this tool. A clean Microsoft-only recapture would require a revised baseline contract. Do not proceed to live WinUSB until this dependency and package trust are resolved.

Next: review the extension-exclusion/restore dependency, choose the exact future trust policy, and prepare a small rollback-backed live authorization only after both blockers are resolved. Keep the currently working controller and research branch intact.
