# TASK 8L - User-mode Chatpad transport research

Date: 2026-10-03 (Asia/Baku). Base: `4759f7f01fe03edd96b66bb75f5c14d732b36016`.
Branch: `research/chatpad-usermode-transport`.

## Verdict and its limits

**`CUSTOM_KERNEL_DRIVER_REQUIRED` for the currently proven architecture that preserves native Xbox/XInput.** No supported pure-user-mode transport or independently bindable WinUSB Chatpad function was established. This is a bounded engineering verdict, not proof that every undocumented facility or future third-party driver is impossible.

**Healthy Microsoft-only live comparison: BLOCKED / outstanding.** The current device fails to start. Its missing interfaces cannot prove what a healthy xusb22 driver exposes. The user confirmed the controller works only in the experimental developer environment and agreed to finish non-mutating research before considering a comparative reboot. No reboot was performed.

The evidence does not justify a transport POC, a WinUSB rebind, or spending on production signing yet. Finish the healthy-stack comparison before closing the driverless question empirically.

## Live device and ownership

Read as a non-elevated user on Windows 11 Pro build 26200:

- One present physical `USB\VID_045E&PID_028E\<serial>` device; PDO `\Device\USBPDO-18`.
- Parent is a started `USB\VID_1A40&PID_0201\<hub-instance>` USBHUB3 hub; connection index 6.
- Selected function driver: Microsoft `xusb22.inf`, service xusb22, version `10.0.26100.9278`.
- Selected extension: `oem104.inf`, original `chatpadfilterextension.inf`, 1.0.14.0.
- Configured device LowerFilters: `vhf`, `ChatpadFilter`; no reported device UpperFilters or XnaComposite class filters.
- **Actual loaded target stack: USBHUB3 only.** Problem 52 (`CM_PROB_UNSIGNED_DRIVER`), PnP ProblemStatus `0xC0000428` (`STATUS_INVALID_IMAGE_HASH`). Services xusb22, ChatpadFilter and vhf are stopped. Do not draw a loaded `xusb22 -> filter` stack for this boot.
- Installed filter file is 73,576 bytes, SHA-256 `16151F574AB93BEA556B08623D8450E48AF5F3308FA82E40FD5CFADBBA76E8C0`, exactly matching the retained TASK 8K signed SYS. It is installed, but not loaded. This supersedes the old continuation's not-installed claim.
- No present IG child, HID child, `MI_00`, `MI_01`, `MI_02`, or `MI_03` target nodes. One non-present HID IG_02 record remains. The old IG_00 chain is historical, not current.
- `XInputGetState(0..3)` returns 1167 (`ERROR_DEVICE_NOT_CONNECTED`) at every index.
- Read-only security observations: registry Secure Boot state 0; Win32_DeviceGuard reports VBS status 2 and running service 2 (memory integrity). This is not a successful Secure Boot/HVCI driver acceptance test. No security setting was changed.

Exact serial-bearing instance IDs, container, symbolic links, Driver Store path and raw PnP properties remain local in ignored `artifacts/task-8l/`. They are intentionally not published in Git. `pnp-stack.txt`, `pnp-properties.json`, `interface-opens.json` and `hub-open.json` contain the exact values requested for local inspection.

## USB descriptors obtained from the actual hardware

A handle to the parent hub opened with desired access 0, share READ|WRITE, OPEN_EXISTING. Documented `IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX` (`0x220448`) succeeded, returning 35 bytes. Device descriptor: USB 2.00, device class/subclass/protocol **FF/FF/FF**, EP0 max packet 8, VID/PID 045E/028E, bcdDevice 0114, one configuration. This revision is the controller's USB descriptor; it does not independently re-query the attached Chatpad's revision.

`IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION` (`0x220410`), configuration index 0, succeeded: 165 bytes including the 12-byte request header and complete 153-byte configuration. Configuration value 1, four interfaces, all alternate setting 0, attributes A0, bMaxPower 250 (500 mA for USB 2). Current configuration value from connection information is 0 and open pipe count is 0 in this failed boot.

| USB interface | Class/subclass/protocol | Endpoints: address, type, max packet, interval |
|---|---|---|
| 0, controller | FF/5D/01 | 81 IN interrupt, 32 bytes, 4; 01 OUT interrupt, 32 bytes, 8 |
| 1, auxiliary/audio protocol | FF/5D/03 | 82 IN interrupt, 32, 2; 02 OUT interrupt, 32, 4; 83 IN interrupt, 32, 64; 03 OUT interrupt, 32, 16 |
| 2, existing Chatpad transport | FF/5D/02 | **84 IN interrupt, 32 bytes, 16** |
| 3 | FF/FD/13 | None |

No interface association descriptor (type 0B) appears. Vendor descriptors 21/41 are present; type 21 in a vendor-class interface is not proof of USB HID. Actual endpoint descriptors take priority over sample tables: this unit's controller OUT endpoint is **01**, not the 02 shown in some example XUSB documentation. Interface 2's physical identity comes from the existing driver/legacy transport, not from calling all vendor interfaces keyboards. A 32-byte endpoint maximum does not change the proven five-byte Chatpad protocol length.

The OS-string 0xEE query failed with Win32 31 (`ERROR_GEN_FAILURE`), both with a large buffer and the exact 18-byte descriptor length. This **does not prove absence of MS OS descriptors**: live PnP compatible IDs include `USB\MS_COMP_XUSB10`, and the read-only USB cache has `osvc` bytes `01 90`, recording a prior successful OS descriptor query/vendor code. Microsoft's [XUSB OS descriptor specification](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-xusbi/601a3107-6583-4e80-867e-118829cb573e) describes XUSB10, not WINUSB. [USB registry documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-device-specific-registry-settings) explains that cache. No WINUSB compatible ID was observed; full vendor OS-feature bytes were not retrieved.

## Published interfaces and ordinary-user handles

Configuration Manager `CM_Get_Device_Interface_List_SizeW` / `CM_Get_Device_Interface_ListW` queried every registered DeviceClasses GUID for each discovered present/non-present VID/PID node, using PRESENT and ALL flags. Read-only registry inspection corroborated the result. Explicit queries also covered the known classes below.

| Interface class GUID | Target result in this boot |
|---|---|
| USB device `{A5DCBF10-6530-11D2-901F-00C04FB951ED}` | No registered/present physical target link |
| XUSB `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}` | No registered/present physical target link |
| HID `{4D1E55B2-F16F-11CF-88CB-001111000030}` | One disabled, non-present IG_02 link; no live HID link |
| Custom control `{63B66B53-8AAE-4F7D-919B-7E1A4F167A04}` | No registered/present target link |
| USB hub `{F18A0E88-C30C-11D0-8815-00A0C906BED8}` | Parent hub link opens successfully; descriptor IOCTLs work |

The retained HID path has the form `\\?\HID#VID_045E&PID_028E&IG_02#<instance>#{4d1e55b2-f16f-11cf-88cb-001111000030}`. Four `CreateFileW` attempts used access 0, GENERIC_READ, GENERIC_WRITE, and READ|WRITE; each used share READ|WRITE, OPEN_EXISTING and FILE_FLAG_OVERLAPPED. **All four returned Win32 2 (`ERROR_FILE_NOT_FOUND`).** No handle existed for ReadFile/WriteFile/DeviceIoControl. Exclusive share modes were not tried because they offer no useful test on a missing link and could interfere on a healthy device.

The exact parent hub link is in `hub-open.json`. Its access-0 open succeeds, including an overlapped-open check; descriptor IOCTLs used a separate synchronous access-0 handle. This demonstrates user-mode descriptor access, not raw endpoint access. Win32 outcomes above are captured directly; no per-call NTSTATUS was measured or guessed. The separate PnP NTSTATUS is stated above.

Absent physical/XUSB/Chatpad links were not fabricated and opened by guessing symbolic names. No arbitrary IOCTLs, endpoint reads, vendor transfers or activation writes were sent. Thus **read/write capability on healthy xusb22 and its HID child remains UNTESTED**, rather than failed with an invented access-denied code.

## Why the available APIs do not establish Chatpad transport

- The existing implementation needs EP0 vendor activation (six exact requests in `ChatpadActivationRequests.c`, including `09 00`), interface commands `41 00 1F/1E 00 02 00 00 00`, one `001B` after the first packet, and reads from interface 2 pipe 0 (live descriptor endpoint 84). `ChatpadLiveRuntime.c` uses kernel `URB_FUNCTION_CONTROL_TRANSFER` and bulk/interrupt URBs below xusb22, observing its completed configuration rather than replacing it.
- [XInput](https://learn.microsoft.com/en-us/windows/win32/xinput/xinput-and-directinput) exposes controller input/feedback. [XInputGetKeystroke](https://learn.microsoft.com/en-us/windows/win32/api/xinput/nf-xinput-xinputgetkeystroke) documents gamepad events; its name is not evidence of wired Chatpad byte access. No documented XInput API found exposes arbitrary USB setup packets or endpoint 84.
- Microsoft explains that the [XUSB HID interface](https://learn.microsoft.com/en-us/windows/win32/xinput/directinput-and-xusb-devices) represents controller state for DirectInput compatibility. A HID collection is not a general USB-pipe handle. No current HID descriptor/report query is possible here because the child is absent.
- The public reverse-engineering header [XInputHooker XUSB.h](https://github.com/nefarius/XInputHooker/blob/master/XInputHooker/XUSB.h) names information, capabilities, controller state, LED, guide, battery, audio, and management operations. It establishes a candidate GUID and known operations, **not a complete audit of this installed xusb22 binary**. It supplies no known Chatpad/raw-control operation. These private IOCTLs were not submitted in this failed stack.
- [IOCTL_INTERNAL_USB_SUBMIT_URB](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/usbioctl/ni-usbioctl-ioctl_internal_usb_submit_urb) is an IRP_MJ_INTERNAL_DEVICE_CONTROL kernel request. Putting its number in user-mode DeviceIoControl cannot reproduce the driver's URB path.
- The successful [hub descriptor request](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/usbioctl/ns-usbioctl-_usb_descriptor_request) forces bmRequest to 80 and bRequest to 06. It cannot be repurposed for activation, keep-alive or interrupt input.
- [WinUSB](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-considerations) requires Winusb.sys to own the target function. Having Winusb.dll, or another unrelated device using Winusb.sys, grants no access to this xusb22-owned device. WinUsb_Initialize was not called on an unrelated hub or a nonexistent target handle.

The five-byte stream is on a distinct physical endpoint, not established as a multiplexed XInput/HID report. It lies within the USB function selected for xusb22. No ordinary-user handle delivering it was found. That finding plus API contracts supports the engineering verdict; Code 52 prevents the stronger healthy-stack empirical exclusion.

## Separate-interface WinUSB assessment

**Not available in the existing topology.** Device class FF/FF/FF does not meet the automatic composite class rules; the target has no USB\COMPOSITE compatible ID, usbccgp parent, or MI child PDOs. Local xusb22.inf matches the whole VID/PID and XUSB10 IDs, not a separately enumerated Chatpad interface. [Microsoft's composite enumeration rules](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/enumeration-of-the-composite-parent-device) distinguish multiple USB interface descriptors from independently bindable PnP functions.

A hypothetical experiment would replace the physical function with usbccgp through a custom INF referencing usb.inf, arrange a compatible child binding for the controller (nominal MI_00), and bind nominal MI_02 (FF/5D/02, endpoint 84) to WinUSB through another INF/interface GUID. This is **not** simply binding an already existing MI_02. It removes xusb22 from its present whole-device role. Whether xusb22 can initialize with only the resulting child resources, retain auxiliary functions, and coexist with the activation's device-recipient requests is unproven. Its original INF contains no matching MI model. No such experiment is justified by a descriptor count alone.

[WinUSB control transfers](https://learn.microsoft.com/en-us/windows/win32/api/winusb/nf-winusb-winusb_controltransfer) could represent the protocol if legitimate ownership existed. They do not solve the ownership prerequisite. A firmware-provided WINUSB OS compatible ID can eliminate a custom INF; none was observed here. A custom [WinUSB package still requires a signed catalog](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation), even though winusb.sys itself is Microsoft-provided. Do not equate no custom SYS with no package/signing/install work.

## Third-party transports and production implications

| Path | Signing / installation | Secure Boot and HVCI | Native Xbox/XInput impact |
|---|---|---|---|
| Pure app over existing xusb22 | No new driver package | Uses existing in-box components | Ideal, but no Chatpad transport established; healthy test outstanding |
| WinUSB on independent interface | In-box SYS; custom INF/catalog normally needed without WINUSB firmware ID | Microsoft SYS; device/package acceptance still required | No independent target PDO; forced split is unproven |
| WinUSB replacing whole function, directly or via libusb | In-box SYS; binding/package change | In-box SYS does not validate the architecture | Replaces xusb22; fails native coexistence requirement |
| libusbK / libusb0 | Third-party kernel SYS and device/package installation; not driverless | Exact distributed binary/signature and HVCI qualification required; not tested | Replacement mode displaces xusb22; filter mode is not proven safe coexistence |
| UsbDk | Third-party bus filter/helper installation | No current binary acceptance/HVCI claim made | Redirection takes exclusive device ownership and detaches normal driver access |
| Current custom KMDF filter + VHF | New retail kernel binary needs Microsoft production signing and signed package | Must separately qualify HVCI and Secure Boot; test signature alone is insufficient | Historically proven coexistence in development; current normal boot fails Code 52 |

The [libusb Windows documentation](https://github.com/libusb/libusb/wiki/Windows) requires a compatible kernel backend; its WinUSB backend cannot bypass xusb22. It discourages UsbDk for stability and libusb0 filter mode. [UsbDk's own architecture](https://github.com/daynix/UsbDk/blob/master/ARCHITECTURE) explicitly acquires exclusive access by detaching the device from its normal drivers. [libusbK](https://github.com/mcuee/libusbk) is a real kernel driver solution, not an ordinary library workaround. No current, maintained third-party shared transport was established that meets this exact coexistence requirement. No third-party installation or HVCI-hostile workaround is recommended.

[Microsoft kernel signing requirements](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-requirements--windows-vista-and-later-) and [memory-integrity compatibility requirements](https://learn.microsoft.com/en-us/windows-hardware/test/hlk/testref/driver-compatibility-with-device-guard) are separate obligations. Production signing does not by itself prove HVCI correctness. No cost estimate or purchase recommendation is made.

## Viable proven path and POC result

Historical development-hardware path, currently unable to load in this normal boot:

```text
Controller whole USB function -> Microsoft xusb22 -> normal Xbox/XInput
                            lower Chatpad KMDF filter
                              | EP0 activation / maintenance
                              | interface 2, interrupt IN 84, five-byte packets
                              -> portable mapper -> Microsoft VHF -> keyboard
```

A small transport filter exposing bounded operations to an app could move mapping/output to `SendInput`, but it would still need a signed custom kernel binary and is not implemented here. The legacy app already depended on `IOCTL_CHATPAD_SEND_CONTROL_TRANSFER` / `IOCTL_CHATPAD_READ_FROM_CHATPAD_ENDPOINT` implemented by its filter; it was not driverless.

**No ChatpadUserModePoc executable was created. No real Chatpad report was acquired in TASK 8L. No SendInput or VHF output was exercised.** Existing parser, Base/Green/Orange mapper and configuration ABI 1 were inspected and left unchanged. Diagnostic C#/PowerShell in ignored artifacts only opens enumerated links and queries descriptors/XInput; it is not a functional Chatpad POC.

## Validation and continuation

- Complete live configuration parsed with descriptor bounds checks: four interfaces / seven interrupt endpoints, all within 153 bytes.
- Existing retained Release x64 protocol executable: **904/904**; control/profile executable: **15/15**. These are reruns of existing artifacts, not a fresh source build or live acceptance. Retained companion/package hashes match TASK 8K.
- `pwsh -NoProfile -File tools/Test-RepositorySafety.ps1`: PASS, including immutable legacy and ignored outputs. Driver/tool source and build configuration were not changed.
- No install/load/sign/package/deploy, driver deletion, rebind, registry write, restart/reboot, security or power change, activation/keep-alive/report read, keyboard injection or IOCTL brute force occurred.

Next task: **TASK 8L-C1 - comparative interface census on a healthy stack**. First preserve this normal-boot baseline. An operator-controlled return to the known development boot can show which interfaces appear when xusb22 starts, but custom-filter presence contaminates any driverless success claim. The decisive sample ultimately requires healthy xusb22 with no Chatpad filter, verified by the actual stack. Changing bindings/removing the installed extension requires a separate concrete, authorized recovery plan with exact target, effect, rollback and reboot requirements; no removal command was executed or implicitly authorized here. Do not weaken security merely to make a driverless demonstration pass.

Local repeat entry point: `pwsh -NoProfile -File artifacts/task-8l/Inspect.ps1`; it contains this machine's hub-port assumption and overwrites its JSON outputs. Before a comparison, copy the baseline into a separate ignored directory and re-resolve the parent/port from PnP. Use `UsbResearchExactString.cs` for exact-size OS-string follow-up. Re-enumerate every published interface, probe safe shared opens, inspect actual HID capabilities, and submit only source-identified non-mutating queries. Build monitor/keyboard only if a legitimate transport first yields real five-byte reports without the custom filter.
