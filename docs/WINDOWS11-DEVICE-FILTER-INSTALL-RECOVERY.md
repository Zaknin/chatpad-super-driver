# Windows 11 Device-Specific Filter Installation and Recovery Design

## 1. Purpose and authorization boundary

This document specifies how a future signed Chatpad filter package could be
staged, attached, verified, and removed without replacing Microsoft's
`xusb22` function driver or changing class-wide filter state. It is a recovery
design, not an installation procedure authorized for execution.

Nothing in this document authorizes creating an INF, catalog, certificate, or
package; signing a binary; changing boot or security policy; staging or
installing a package; restarting a device; loading a driver; opening a device;
or sending traffic. Every command below is a future-run template and must be
executed only by a later task that names the exact package, machine, action,
limits, and rollback owner.

The repository contains one isolated source-controlled INF prototype at
`prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf`. It is not
part of a package project or driver build. The current `ChatpadFilter.sys`
outputs are unsigned compile-only artifacts and are not eligible for staging,
installation, or loading.

## 2. Fixed target and preserved base driver

The only permitted target is the physical controller devnode whose hardware
ID is exactly:

```text
USB\VID_045E&PID_028E
```

The revision-specific ID may be present, but revision `0114` is evidence from
one observed controller and is not the package target unless a later
compatibility decision narrows it deliberately.

The package must preserve all of these baseline facts:

- class `XnaComposite`, GUID `{D61CA365-5AF4-4486-998B-9DB4734C6CA3}`;
- Microsoft base INF `xusb22.inf`;
- Microsoft function service `xusb22` and binary `xusb22.sys`;
- related `IG_01` and HID descendants remain bound to their Microsoft drivers;
- no `UpperFilters` or `LowerFilters` value is added to an `XnaComposite`,
  `HIDClass`, USB, or other class key;
- no base-driver replacement, WinUSB binding, compatible-ID-wide match, or
  class-wide match occurs.

The package must match the exact two-part hardware ID, not a class ID,
compatible ID, wildcard, container ID, or the related HID branch. Discovery
of more than one present matching physical controller is a hard stop until a
later task explicitly scopes and identifies each intended instance.

## 3. Future package model

The future package should be a Windows extension driver package that targets
the exact controller hardware ID and adds a non-associated filter service. It
must not claim function-driver ownership and must not replace `xusb22.inf`.

On Windows 10 version 1903 and later, Microsoft documents device-specific
filter registration through a model-specific `DDInstall.Filters` section and
an `AddFilter` directive. The future package must use declarative filter
metadata with `FilterPosition=Lower`. It must not directly write a device
`LowerFilters` value with `AddReg`, and it must never write a class key.

The future INF review must prove all of the following before package creation
is accepted:

- the Models entry contains only `USB\VID_045E&PID_028E`;
- the package is an extension INF with a stable, project-owned `ExtensionId`;
- the filter service name is stable and exactly matches the `AddFilter` name;
- the service is a kernel driver with demand/PnP start semantics;
- the service is not marked `SPSVCINST_ASSOCSERVICE`;
- the binary is copied to Driver Store isolation destination DIRID 13;
- `FilterPosition=Lower` is used because `xusb22.inf` exposes no reviewed
  project-owned filter level;
- there is no class installer, co-installer, executable installer, custom
  action, `UpperFilters`, direct `LowerFilters`, or base binding replacement;
- architecture, target OS, KMDF version, catalog, and signature declarations
  match the actual built package;
- uninstall removes only this extension package and service metadata.

Declarative lower position does not by itself prove the resulting order is
safe or that default-control and input traffic are visible. Effective stack
order must be captured after a separately authorized install and compared to
the approved stack expectation before any transport experiment.

## 4. Package identity ledger

A future package task must produce an immutable local recovery ledger before
staging. The ledger stays outside Git under a restricted local recovery
directory and contains:

- original INF filename and SHA-256;
- catalog filename and SHA-256;
- driver binary filename, version, and SHA-256;
- signer subject, certificate thumbprint, chain result, and signing policy;
- provider, class, `DriverVer`, `ExtensionId`, service name, and KMDF version;
- exact hardware ID list extracted from the package;
- package validation results;
- the published `oem#.inf` assigned after staging;
- the exact target instance ID selected at authorization time;
- baseline and post-action timestamps in UTC;
- operator, authorization reference, and rollback owner.

The published name is the removal identity. Never guess it from sequence,
reuse an `oem#.inf` from an older run, or infer it from a friendly name. The
future staging step must correlate provider, original name, version, date,
signer, and package file hashes to the newly assigned published name.

## 5. Recovery prerequisites

All prerequisites are hard gates. A future installation task must stop before
staging if any item is missing:

1. A second input method independent of the target controller is connected
   and verified.
2. An administrator account and an elevated command shell are available.
3. The BitLocker recovery key, if device encryption is active, is available
   off the machine.
4. Windows Recovery Environment is enabled and its entry path is known.
5. Bootable Windows recovery or installation media is available if Windows RE
   cannot start.
6. The recovery ledger and command sheet are available offline, not only on a
   network share or the affected machine.
7. The exact package and published name are recorded before any restart.
8. `xusb22` is healthy, the target problem code is zero, and the controller's
   baseline input behavior is verified by a later explicitly authorized check.
9. No unexpected device-level or class-level filter is present.
10. Secure Boot and Memory Integrity/HVCI state are recorded and remain at the
    approved secure baseline.
11. No pending restart, Windows Update driver operation, Device Manager
    operation, or other driver-store mutation is active.
12. A rollback owner remains present through post-install verification.

A restore point may be created as defense in depth by a separately authorized
system-change task, but it is not the primary rollback mechanism. Package
identity plus PnPUtil removal is the primary path; offline DISM removal is the
last-resort path.

## 6. Read-only baseline capture templates

These commands are templates for a future elevated PowerShell session. They
must use the exact instance ID found by a separately authorized inventory;
`<...>` placeholders must never be passed literally. Output belongs under a
restricted local recovery directory or ignored `artifacts/`, never in Git.

```powershell
$TargetInstanceId = '<exact USB instance ID>'
$RecoveryRoot = 'C:\ProgramData\ChatpadSuperDriver\Recovery\<UTC timestamp>'
New-Item -ItemType Directory -Path $RecoveryRoot

pnputil /enum-devices /instanceid $TargetInstanceId /deviceids /relations /services /stack /drivers /interfaces /properties |
    Out-File "$RecoveryRoot\target-before.txt" -Encoding utf8
pnputil /enum-drivers /files |
    Out-File "$RecoveryRoot\third-party-drivers-before.txt" -Encoding utf8
driverquery /v /fo csv |
    Out-File "$RecoveryRoot\driverquery-before.csv" -Encoding utf8
sc.exe qc xusb22 |
    Out-File "$RecoveryRoot\xusb22-service-before.txt" -Encoding utf8
sc.exe query xusb22 |
    Out-File "$RecoveryRoot\xusb22-state-before.txt" -Encoding utf8
Confirm-SecureBootUEFI |
    Out-File "$RecoveryRoot\secure-boot-before.txt" -Encoding utf8
Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard |
    Format-List * |
    Out-File "$RecoveryRoot\device-guard-before.txt" -Encoding utf8
```

The future task must also run the repository's read-only connected-device
inventory and retain its raw output locally. It must compare the target,
parents, children, service, INF, filters, problem code, and interfaces with the
committed sanitized baseline.

## 7. Driver-store and registry backup/export

PnPUtil enumerates and exports third-party packages, not Windows inbox
packages such as the Microsoft base `xusb22.inf`. Recovery therefore does not
depend on exporting or replacing `xusb22`; it depends on leaving that base
package installed and removing only the project extension package.

Before staging, a future authorized task must export the current third-party
Driver Store inventory and save its command result:

```powershell
New-Item -ItemType Directory -Path "$RecoveryRoot\third-party-driver-export"
pnputil /export-driver * "$RecoveryRoot\third-party-driver-export" |
    Tee-Object -FilePath "$RecoveryRoot\driver-export-result.txt"
```

It must export, for evidence only, the exact target instance key and relevant
service/class keys. These exports contain machine-specific data and must not be
committed:

```powershell
$InstanceKey = 'HKLM\SYSTEM\CurrentControlSet\Enum\USB\<exact instance subkey>'
reg.exe export $InstanceKey "$RecoveryRoot\target-instance-before.reg" /y
reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Services\xusb22' "$RecoveryRoot\xusb22-service-before.reg" /y
reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\Class\{D61CA365-5AF4-4486-998B-9DB4734C6CA3}' "$RecoveryRoot\xna-class-before.reg" /y
```

Registry exports are forensic comparison material, not an automatic restore
script. The primary rollback must let Windows uninstall the exact extension
package. Importing an entire Enum or class key can overwrite unrelated state
and is prohibited unless a later emergency-recovery task reviews an exact,
minimal value-level repair.

After staging, the future task must export the newly published project package
by exact name into the recovery bundle and verify its files against the source
ledger:

```powershell
pnputil /export-driver <verified-oem#.inf> "$RecoveryRoot\project-package-export"
```

## 8. Future staged installation sequence

The sequence deliberately separates package creation, signing, staging,
attachment, loading, and hardware interaction.

### Gate I1 - package creation authorization

Allows only creation of the extension INF/package source and offline
validation. It does not allow signing, staging, or installation.

### Gate I2 - signing authorization

Allows only the named package to be signed through an approved test or
production path. It does not allow trust-store, Secure Boot, HVCI, BCD, Driver
Store, or device changes.

### Gate I3 - staging authorization

After baseline capture and package identity verification, stage without
`/install`:

```powershell
pnputil /add-driver '<absolute path to verified INF>'
```

Capture the output, identify the assigned `oem#.inf`, update the ledger, export
that exact package, and rerun the complete target and Driver Store inventory.
Staging must not change the effective device stack. Any device restart,
service load, new filter, base binding change, or ambiguous package identity is
a hard stop followed by removal of the staged package.

### Gate I4 - attachment and load authorization

Only a later task that explicitly names the verified published package and
target instance may request installation on existing matching devices:

```powershell
pnputil /add-driver '<absolute path to verified INF>' /install
```

Do not add `/reboot`; preserve the tool's exact result first. If Windows says a
restart is required, stop, capture state, and obtain the already-planned reboot
authorization. Do not use Device Manager, DevCon, a custom installer, direct
registry writes, or broad `/deviceid` operations as alternate install paths.

Installation must occur with the controller idle and all nonessential software
closed. It must never be combined with transport requests, descriptor access,
activation, input capture, Driver Verifier changes, or unrelated driver work.

### Gate I5 - device interaction authorization

Package attachment and load do not authorize opening a device or sending a
request. Transport visibility and any later USB action remain separate gates.

## 9. Immediate post-install verification

Before any transport action, the future task must establish all of these facts:

- the exact physical target is present, started, and has problem code zero;
- base INF remains `xusb22.inf`, function service remains `xusb22`, and the
  Microsoft binary remains in the effective stack;
- the project service appears exactly once as a lower filter on the intended
  physical devnode;
- no `XnaComposite`, `HIDClass`, or USB class filter value changed;
- no unrelated `045E:028E` instance was altered without authorization;
- the related `IG_01` and HID descendants remain healthy;
- Secure Boot and Memory Integrity/HVCI state are unchanged;
- ordinary controller/XInput enumeration and input match the approved
  baseline;
- no unexpected reboot, bugcheck, device flap, repeated PnP start failure, or
  Code Integrity failure occurred.

Capture the same command set as the baseline using `*-after` filenames and
produce a machine-local diff. A successful install is not a successful
transport test.

## 10. Hard abort criteria

Stop immediately and enter rollback if any of these occurs:

- target identity is ambiguous or differs from the ledger;
- published package identity or hashes cannot be proven;
- the package replaces `xusb22`, changes a class key, or affects another device;
- the target or a child reports a nonzero problem code or disappears;
- ordinary controller input degrades, hangs, duplicates, or changes timing;
- the filter service fails to start or repeatedly starts/stops;
- Windows requests an unplanned security, boot-policy, or firmware change;
- Secure Boot or HVCI is disabled or changes state;
- the machine loses its independent keyboard/input or recovery path;
- a bugcheck, boot loop, Code Integrity rejection, or unexpected restart occurs;
- normal package removal cannot identify exactly one project `oem#.inf`.

No fallback may weaken security, install an unsigned artifact, use `/force`,
edit the registry, or remove a devnode unless the corresponding recovery step
was preauthorized.

## 11. Normal rollback

Normal rollback removes the exact project extension package while leaving
`xusb22.inf` and the physical devnode intact:

```powershell
pnputil /delete-driver <verified-oem#.inf> /uninstall
```

Do not use `/force` initially. Capture the complete output. If a restart is
requested, capture pre-restart state and use the authorized recovery reboot.
After restart, run `/scan-devices` only if the approved procedure calls for it;
do not remove, disable, enable, or restart the devnode as an improvised fix.

Rollback is complete only when the verification in section 14 passes. A
command exit code of zero is necessary but not sufficient.

## 12. Safe Mode recovery

If normal Windows starts but the controller stack is unhealthy, use the
independent keyboard and an elevated shell to run normal rollback. If the GUI
or ordinary boot is unusable, enter Windows RE and choose:

```text
Troubleshoot -> Advanced options -> Startup Settings -> Restart
             -> Safe Mode with Command Prompt
```

BitLocker may require the recovery key. In Safe Mode, first verify the exact
published package from the offline recovery ledger, then run:

```text
pnputil /delete-driver <verified-oem#.inf> /uninstall
```

If the package is still reported in use, stop and preserve the result. The
`/force` option is an escalation, not a routine fallback. It may be used only
when the recovery authorization names the exact package and accepts the
restart requirement:

```text
pnputil /delete-driver <verified-oem#.inf> /uninstall /force /reboot
```

Never remove `xusb22.inf`, `input.inf`, or any Microsoft inbox package.

## 13. Offline Windows RE recovery

If installed Windows cannot boot even in Safe Mode, use Windows RE or trusted
recovery media. Determine the installed Windows volume by inspection; do not
assume it is `C:` in Windows RE. Then list third-party packages and correlate
the exact published name to the recovery ledger:

```text
dism /Image:<WindowsVolume>:\ /Get-Drivers /Format:Table
dism /Image:<WindowsVolume>:\ /Get-DriverInfo /Driver:<verified-oem#.inf>
```

Only after identity is exact may the last-resort removal run:

```text
dism /Image:<WindowsVolume>:\ /Remove-Driver /Driver:<verified-oem#.inf>
```

DISM removal is restricted to the project's third-party extension package.
Do not use `/ForceUnsigned`, manually delete Driver Store files, or remove a
default/boot-critical driver. Preserve `dism.log`, reboot normally, and run the
full rollback verification.

## 14. Rollback verification

Rollback succeeds only if all of these are true after the required reboot or
PnP restart:

1. The project `oem#.inf` is absent from `pnputil /enum-drivers /files`.
2. The project service is absent or no longer registered to the target stack.
3. The target's base INF is `xusb22.inf` and service is `xusb22`.
4. The target and related child nodes are present with problem code zero.
5. Effective stack output contains no project filter.
6. Device and class filter state equals the captured baseline.
7. Secure Boot and Memory Integrity/HVCI equal the captured baseline.
8. Ordinary controller/XInput behavior matches the pre-install baseline.
9. No unrelated device, package, service, or class key changed.
10. The repository and ignored build artifacts remain unrelated to the system
    recovery operation.

Any mismatch keeps Gate F failed. Preserve the recovery bundle and stop; do not
continue into transport visibility or hardware work.

## 15. Signing, Secure Boot, and HVCI policy

The current unsigned `.sys` cannot be installed or loaded. On 64-bit Windows,
kernel code must be signed. A PnP package also requires a valid package/catalog
signature for normal automated installation.

Memory Integrity/HVCI is a security boundary, not a test inconvenience. When
HVCI is enabled, even test-mode code must have a binary signature. Compatibility
must be validated with HVCI and Secure Boot left in their normal enabled state
for the target scenario.

This project rejects the following as installation or recovery strategies:

- disabling Secure Boot;
- disabling Memory Integrity/HVCI or VBS;
- enabling `TESTSIGNING` through BCD on this machine;
- using the one-boot "Disable driver signature enforcement" option to bypass
  package acceptance;
- importing an unreviewed test certificate into a trust store;
- installing an unsigned package or using DISM `/ForceUnsigned`;
- treating a successful signature check as transport or runtime safety proof.

If future development needs test signing, it requires its own explicit task,
preferably on a noncritical dedicated test system. Production or
preproduction signing with Secure Boot and HVCI preserved is a separate
release/security decision.

## 16. Controller-preservation checklist

Before and after each authorized mutation, compare:

- exact target instance ID, hardware IDs, parent, children, and container;
- base INF/provider/version/signer and function service;
- effective service stack and compound lower-filter properties;
- device and class `UpperFilters`/`LowerFilters` state;
- PnP status, problem code, present state, and interface registrations;
- independent XInput/controller enumeration and representative controls;
- Windows System and Code Integrity event logs for the bounded time window;
- Secure Boot and HVCI state;
- unrelated devices sharing the external hub.

No Chatpad activation, response interpretation, endpoint access, continuous
reader, or key presentation belongs in this checklist.

## 17. Authorization matrix

| Gate | Permitted action | Required evidence | Explicitly still prohibited |
| --- | --- | --- | --- |
| I1 | Create and statically validate package source | Reviewed exact-ID extension-INF design | Signing, staging, install, load |
| I2 | Sign one named package | Package hashes, signer policy, clean I1 result | Trust/security changes, staging |
| I3 | Stage one verified package | Recovery bundle, exact hashes, rollback owner | `/install`, restart, load, device access |
| I4 | Attach/load on one exact instance | Healthy baseline, verified `oem#.inf`, signed authorization | USB traffic, activation, input capture |
| I5 | Observation-only stack visibility | Post-install preservation PASS and separate experiment plan | Activation or unbounded requests |
| I6 | Bounded device interaction | Gates F/G/H and exact request/abort budget | Any action beyond the named experiment |

Authorization for a later gate does not imply authorization for an earlier
unfinished gate or a later action.

## 18. Design result and remaining proof boundary

This design satisfies the documentation part of installation-recovery Gate F:
the target, package model, backups, staged order, normal/Safe Mode/offline
rollback, security posture, verification, and abort criteria are explicit.

Gate F is not operationally passed until the specification is independently
reviewed against an actual signed package identity and demonstrated on a
noncritical test system without weakening security. Gate G remains entirely
open: no default-control or Chatpad-input visibility has been proven.

## 19. Offline extension-INF and package-closure checkpoints

The isolated prototype now statically represents the selected package model:

- Extension class and stable project-owned `ExtensionId`
  `{69E7CCD7-7011-4059-95D4-618974E126DD}`;
- AMD64 Windows 11 build 22000 or later;
- exact model match `USB\VID_045E&PID_028E`;
- non-associated demand-start kernel service `ChatpadFilter`;
- `ChatpadFilter.sys` at DIRID 13 and KMDF `1.15`;
- declarative `AddFilter` with `FilterPosition=Lower`;
- future catalog identity `ChatpadFilterExtension.cat`.

WDK 10.0.26100.0 `InfVerif /k /v` reports the INF valid. Repository semantic
guards independently reject broadened IDs, direct filter-registry writes,
class filters, function-driver replacement, boot start, co-installers,
commands, absolute paths, build/package references, and package/signing files.

Unsigned offline package/catalog closure is now complete for the exact
validated INF and exact unsigned Release SYS. Inf2Cat returned exit `0` with no
warnings or errors for `10_CO_X64,10_NI_X64,10_GE_X64`. The generated unsigned
catalog remained ignored beneath `artifacts/`. See
[Offline Inf2Cat Package Validation](OFFLINE-INF2CAT-PACKAGE-VALIDATION.md).

This closure does not authorize or prove signing trust, staging, installation,
service or registry mutation, effective placement beneath `xusb22`, controller
preservation, recovery, transport visibility, activation, input, or runtime
behavior. No Driver Store entry or device stack was created or changed. Gate F
remains operationally unresolved.

## 20. Primary references

- Microsoft Learn, [Install a filter driver](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/installing-a-filter-driver)
- Microsoft Learn, [Device filter driver ordering](https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/device-filter-driver-ordering)
- Microsoft Learn, [Using an extension INF file](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/using-an-extension-inf-file)
- Microsoft Learn, [PnPUtil command syntax](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)
- Microsoft Learn, [How devices and driver packages are uninstalled](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/how-devices-and-driver-packages-are-uninstalled)
- Microsoft Learn, [DISM driver servicing command-line options](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-driver-servicing-command-line-options-s14?view=windows-11)
- Microsoft Support, [Windows startup settings](https://support.microsoft.com/en-us/windows/windows-startup-settings-1af6ec8c-4d4a-4b23-adb7-e76eef0b847f)
- Microsoft Learn, [Enable loading of test-signed drivers](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/the-testsigning-boot-configuration-option)
- Microsoft Learn, [Code integrity checking](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/code-integrity-checking)
