# Proposed reversible whole-device experiment — NOT EXECUTED

Prepared in TASK 8L-C1, 2026-10-03. Companion [research and evidence](CHATPAD-WHOLE-DEVICE-WINUSB-RESEARCH.md). This plan does not authorize installation, signing, trust changes, physical binding changes, driver execution or reboot. C1 performs none of them.

## Objective and scope

Prove, in separately recorded stages, real physical controller input under WinUSB, real Chatpad five-byte transport, system-visible virtual Xbox input, reverse physical rumble, and mapped keyboard transitions. Then restore the exact pre-experiment binding and verify it. Use one attached original 045E:028E controller and HIDMaestro **v1.10.1 standard `xbox-360-wired`**, pinned source `1c126ed4780322454391b7be782230b35b0810f6`; no composite/USB-IP persona.

The currently healthy host is TESTSIGNING-enabled. A functional trial in that boot cannot prove ordinary-boot package acceptance. Treat those as two distinct gates. No silent BCD/security change is part of this experiment. Normal-boot/Secure Boot qualification needs a later explicitly chosen environment/boot window. Restoring the test-signed filter in a non-TESTSIGNING boot would restore its binding but reproduce Code 52; it must never be reported as healthy rollback.

## 0. Preparation before any live permission request

Next task should prepare inspectable user-mode tools and a draft package, without executing a backend installer or binding operation:

- Build a bounded native WinUSB monitor/bridge using the existing portable parser and activation tables; managed helper for the supported HIDMaestro SDK. No custom SYS. Separate monitor-only, virtual-only, and bridge modes. Virtual mode must never call InstallDriver implicitly.
- Implement strict report sizes/types, independent trigger/stick mapping, async cancellation, output copying/validation, explicit all-up/neutral/zero-rumble shutdown and a finite timeout. Log raw bytes/timestamps/status locally; a successful keyboard test must correlate with real captured packets.
- Prepare a separate XInput consumer that loads the system DLL, records every return code and proves target-slot identity by a known controlled pattern. Do not assume slot 0. Provide XInputSetState feedback capture and a distinct WGI/GameInput probe. Repair/wrap upstream benchmarks that return success despite timeouts.
- Prepare scoped installation/binding/rollback operations with dry-run output listing exact instance, INF path/hash, catalog, certificate thumbprints, packages and property changes. The old `Invoke-ChatpadExactInstanceBindingRestoration.ps1` entrypoint still reports a non-executing scaffold; it is **not** a ready WinUSB rollback command.
- Keep generated files in ignored `artifacts/task-8lc2/`. No INF signing/package staging in this preparation unless the subsequent task explicitly authorizes those exact actions. Check draft INF with available static tooling only.

### Exact proposed binding INF

This is a reviewable draft, not a generated/signed/InfVerif-validated package. `DriverVer` must be validated against the actual package date. New application interface GUID is `{7D98D36F-5A4B-4A5B-AC39-25F26575D03A}`; it must not reuse our filter control GUID.

```ini
[Version]
Signature="$Windows NT$"
Class=USBDevice
ClassGuid={88BAE032-5A81-49F0-BC3D-A4FF138216D6}
Provider=%Provider%
CatalogFile=ChatpadWholeDeviceWinUSB.cat
DriverVer=10/03/2026,0.0.1.0
PnpLockdown=1

[Manufacturer]
%Provider%=Models,NTamd64.10.0...22000

[Models.NTamd64.10.0...22000]
%Description%=WholeDevice,USB\VID_045E&PID_028E

[WholeDevice.NT]
Include=winusb.inf
Needs=WINUSB.NT

[WholeDevice.NT.Services]
Include=winusb.inf
Needs=WINUSB.NT.Services

[WholeDevice.NT.HW]
AddReg=ApplicationInterface

[ApplicationInterface]
HKR,,DeviceInterfaceGUIDs,0x00010000,"{7D98D36F-5A4B-4A5B-AC39-25F26575D03A}"

[Strings]
Provider="Chatpad Super Driver Project"
Description="Xbox 360 whole-device WinUSB experiment"
```

No CopyFiles/custom ServiceBinary, coinstaller, MI target, class-wide filter or filter registration. Windows supplies winusb.sys. Create/sign a catalog covering the exact INF only in an authorized preparation/install task. Package trust is separate from the Microsoft signature on winusb.sys. A local internal-test signer requires its chain in LocalMachine Root and signer in TrustedPublisher; inventory pre-existing trust before any import. Public deployment needs its own release-signing policy. [Microsoft package instructions](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation).

## 1. Capture and preconditions immediately before a live trial

Resolve `$targetId` from the fresh local inventory, then require exactly one present physical `USB\VID_045E&PID_028E` target matching the operator-selected device. Do not publish its serial. Record all matching disconnected instances too, because an INF matches hardware IDs, not just one instance.

Run read-only capture, saving output and exit codes under a new attempt directory:

```powershell
pnputil /enum-devices /instanceid "$targetId" /relations /services /stack /drivers /interfaces /properties
pnputil /enum-drivers /files
Get-CimInstance Win32_SystemDriver | Where-Object Name -in 'xusb22','ChatpadFilter','vhf','WinUSB'
```

Also capture exact physical SPDRP_LOWERFILTERS/UPPERFILTERS including registry type and order; function INF, extension INF(s), service image path/hash, devnode problem/status, XInput slots, parent/port, all child identities, certificate stores, existing virtual backends and effective CI flags. Save fresh hub descriptors; do not rely on the old port number. Query setup-class filters read-only to confirm none would contaminate the WinUSB trial.

Preflight must identify the installed extension by original name/version/hash, not assume the OEM number remains 104. Current known rollback files are:

`artifacts/task-8k-legacy-layers-configuration-package/final/ChatpadFilterExtension.inf`, `.cat`, and `ChatpadFilter.sys`.

| File | Expected SHA-256 |
|---|---|
| INF | FE35416537D432CDB37B0B9C967298F86B2EE636F02937DE3AAB0F1E91FFB274 |
| SYS | 16151F574AB93BEA556B08623D8450E48AF5F3308FA82E40FD5CFADBBA76E8C0 |
| CAT | 6D9724DF174383F37EB9DFC13C2A096BD067BD98F037F7C0A29F8292DD8F0732 |

An authorized live task should additionally `pnputil /export-driver <captured-extension-oem.inf> <new-empty-backup-directory>` and verify all exported hashes before mutation. Preserve the inbox xusb22 package and identify the exact captured xusb22 compatible model from `%SystemRoot%\INF\xusb22.inf`. Stop on missing rollback material, unexpected extra filters, other devices depending on the extension, active other HIDMaestro consumers, ambiguous instance selection or policy mismatch. Do not delete an inbox package.

## 2. Qualify the virtual backend independently

After explicit authorization naming HIDMaestro installation and certificate changes, install only the pinned standard UMDF packages. Capture resulting OEM INF names, DLL/CAT hashes, signer thumbprints, trust-store delta and service/devnode changes. Review `HMContext.InstallDriver` cleanup first: it may remove all HIDMaestro virtuals, so require no unrelated consumers and snapshot prior state.

Create one virtual Xbox while the physical controller remains untouched. Identify the **new** slot/device and prove A press/release, all D-pad directions, both triggers simultaneously, full sticks and neutral using a separate system-XInput process. Call XInputSetState with independent motor values and require callback data/source/length to match; capture zero-rumble feedback too. Check WGI entity count (one) and GameInput separately. Dispose and require removal, then create once more to verify no duplicate/orphan slot. These synthetic states test only the backend, not physical transport or Chatpad.

Stop before physical changes if installation, trust, slot identity, input, feedback or disposal fails. A pass while TESTSIGNING is on is labeled **functional only**. Ordinary-boot acceptance must be repeated with TESTSIGNING off and security policy unchanged, in a later authorized window; do not infer it from this pass or an installer's Authenticode status.

## 3. Exact physical change, one target, one attempt

All following mutations require the later task's explicit live authorization and reviewed concrete tools/package hashes. Do not run them during C1.

1. Close the test virtual and applications using the physical controller. Keep an independent keyboard/mouse and rollback terminal available.
2. Temporarily remove only the captured Chatpad extension package, after proving no other device depends on it. Proposed command: `pnputil /delete-driver <captured-extension-oem.inf> /uninstall`, **without** `/force` or `/reboot`. This command is package-wide, so dependency inventory is a required scope check. If other devices use it, this plan stops for an exact-instance alternative; it does not silently expand scope.
3. Read back target filters. Extension AddReg values can survive removal. If they still contain exactly the captured `vhf` / `ChatpadFilter` entries, the reviewed exact-instance tool removes those two entries from **that device's** SPDRP_LOWERFILTERS, preserving all other names/order/type and comparing the old value before writing. Never delete a class filter, a service, an entire registry branch, or an unexpected filter value. Record whether the original property was absent versus empty. Stop on drift.
4. Stage the exact signed experimental INF with `pnputil /add-driver <absolute-ChatpadWholeDeviceWinUSB.inf>` (no `/install`). Capture its assigned OEM name. PnPUtil `/install` does not force a lower-ranked driver and is not an exact-instance selector.
5. Select only `$targetId` using Device Manager: verify **Details → Device instance path**, then **Update driver → Browse my computer → Let me pick → Have Disk**, choose the exact experimental INF and its single model. Alternatively, implement the same scoped operation with SetupDiOpenDeviceInfoW, device install parameters `DI_ENUMSINGLEINF` / exact DriverPath, compatible driver enumeration/identity verification and DiInstallDevice on that SP_DEVINFO_DATA. No broad hardware-ID update or remove/rescan loop. Record NeedReboot; do not automatically reboot.
6. Query actual stack, service, selected INF, problem status and interfaces. Require WinUSB as physical function, no ChatpadFilter/VHF in that target stack, new interface GUID present, and XInput physical slot absent. A still-loaded service belonging elsewhere is not itself target contamination. If the stack did not rebuild, allow only the separately authorized single exact-device restart; if reboot is requested, stop for the planned operator window.

Expected effect: **normal physical XInput and filter-produced Chatpad keyboard disappear**. No gamepad will work through XInput until the bridge creates/submits a virtual controller. USB headset/accessory behavior is not preserved by this initial experiment.

PnPUtil semantics: [Microsoft command reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax). Exact-instance installation: [DiInstallDevice](https://learn.microsoft.com/en-us/windows/win32/api/newdev/nf-newdev-diinstalldevice).

## 4. Prove physical transport before virtual/keyboard integration

Open new GUID with RW/share RW/OVERLAPPED. Require successful WinUsb_Initialize; query descriptors, alternate settings and pipes. Enumerate associated indexes and verify IF0/1/2/3 identity, not just return count. Require IF0 IN81/OUT01 and IF2 IN84. Keep IF1 untouched.

Monitor-only phase: bounded capture of actual IF0 reports while the operator moves each stick, both triggers and buttons. Check header/length and correlate decoded values. No virtual controller/SendInput yet. Controller readiness must be observed before running the known Chatpad activation state machine; no arbitrary vendor-request scan, broad stall suppression or reset fallback.

Chatpad phase: execute the six exact requests and the existing keepalive/one-shot-001B protocol from the research report. Read IF2/84 and save actual five-byte messages with timestamps and exact return/transfer lengths. Require real type-00 key-down and key-up, plus Base/Green/Orange modifier cases; F0 status or an endpoint existing is not success. Initially decode/log only. Use a finite window and stop on device loss or unexpected protocol failure. This is the independent Chatpad transport acceptance gate.

## 5. Integrate the complete paths

- Submit physical controller state to one target virtual; separate XInput observer must match ABXY, bumpers, Back/Start, stick clicks, D-pad incl. diagonals, independent simultaneous triggers and full signed stick ranges. Test Guide with a suitable consumer and record its API limitations.
- Send bounded nonzero/zero XInput rumble; require callback, exact physical OUT01 packet, and operator-confirmed correct motors/stop. Test player LED only with an explicit valid pattern, record relation to virtual slot.
- Enable SendInput only after captured real Chatpad data passes. Check press/release and Base/Green/Orange chords in a normal desktop text consumer; log injected scan-code transitions and no stuck modifiers. Elevated targets/secure desktop are separate compatibility boundaries.
- Measure physical receipt→virtual observed transition with QPC and report median/p95/p99/max, failures and sample count; do not label SubmitState-only latency physical latency. Include idle CPU, disconnect/reconnect, port change, process restart and sleep/resume when those exact actions are authorized. Never change USB power settings to mask a failure.
- On timeout/unplug/stop: cancel readers, attempt zero rumble while transport exists, release every injected held key, neutralize/dispose virtual, close WinUSB handles. Controlled crash tests require a watchdog and explicit action scope; process death cannot execute its own cleanup.

## 6. Exact rollback and acceptance

Rollback is required even if all trial stages pass, unless a later user instruction explicitly retains the experimental binding.

1. Stop bridge; all-up/neutral/zero rumble; dispose the owned virtual. Close handles before binding restoration.
2. On the exact captured physical instance use Device Manager **Have Disk** with `%SystemRoot%\INF\xusb22.inf`, selecting the captured compatible Xbox 360 model; or the same exact-instance native contract with captured SP_DRVINFO_DATA identity. Check selected base INF/service afterwards. Do not uninstall/delete the inbox package.
3. Once no device uses the experimental WinUSB package, delete only its recorded OEM INF with `pnputil /delete-driver <experiment-oem.inf>` (no `/force`, no wildcard, no `/uninstall`). A busy/error result is a failure to investigate, not permission for broader cleanup.
4. Re-add the hash-verified retained/exported Chatpad extension using `pnputil /add-driver <absolute-verified-ChatpadFilterExtension.inf> /install` only after repeating the single-dependency/matching-device check. Its new OEM number may differ; verify original identity/version/hash, not number equality. Restore the exact captured device filter property if extension application did not reproduce it, using compare-before-write and preserving unrelated entries. Never edit class filters.
5. Perform only the agreed exact-device restart if required. Stop on NeedReboot for operator action. On the original TESTSIGNING boot require problem 0, xusb22→ChatpadFilter→vhf target stack, exact installed SYS hash, all child nodes healthy, real physical XInput motion and Chatpad key release. Compare against the prior control-path defect: status/diagnostics error 87 is a known baseline defect, not a newly introduced success requirement.
6. Remove only this experiment's virtual devices/packages if they were newly introduced and no other consumer now uses them. Use recorded package identities/dependencies; avoid a global “remove all virtual controllers” command on a shared machine. Remove only newly added, now-unused certificate entries by exact thumbprint from their recorded stores; preserve pre-existing certificates and the existing Chatpad signer. Record private-key cleanup if a new signer was created. Do not run downloaded unrelated uninstallers.
7. Capture final binding/filter/service/hash/CI/trust/package/device deltas and XInput/Chatpad acceptance. Require no unexpected persistent changes and no orphan virtual. Save exact commands, return codes, artifacts and failure point. Report FAILED/BLOCKED if restoration cannot be verified; never keep experimenting after losing the known-good recovery path.

## Decision gates

| Gate | PASS evidence | Failure implication |
|---|---|---|
| Virtual-only | Correct system XInput identity/state/feedback/disposal | Backend not suitable yet; physical target remains untouched |
| WinUSB monitor | Exact stack plus valid live IF0 and IF2 traffic | Whole-device Windows transport not proven; rollback |
| Complete bridge | Real controls + physical rumble + real-key-correlated keyboard | Specific integration missing; no production migration |
| Lifecycle/latency | No duplicate/stuck input, bounded recovery and measured overhead | Reliability work required |
| Rollback | Exact original binding, image and real input restored | Experiment not complete; prioritize recovery |
| Normal policy | Repeat install/load/function with TESTSIGNING off, appropriate unchanged Secure Boot/HVCI policy | Production compatibility remains UNTESTED/FAILED; do not weaken policy |
