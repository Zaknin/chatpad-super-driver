# TASK 8L-C1 — Healthy stack and whole-device replacement research

Research date: 2026-10-03. Starting commit: `51dbe52d0f926afbcac714fbef7d2cc76dde102a`, branch `research/chatpad-usermode-transport`. This is research and an experiment design, not an implemented or installed bridge. Raw evidence is ignored under `artifacts/task-8lc1/`; exact device instances and symbolic links remain there.

## Conclusion and recommendation

**`WHOLE_DEVICE_WINUSB_BRIDGE_FEASIBLE` + `USERMODE_WITH_UMDF_VIRTUAL_CONTROLLER_FEASIBLE`, at source-backed architecture level; end-to-end Windows hardware acceptance UNTESTED.** The real device has the required controller and Chatpad endpoints in one configuration. A whole-device WinUSB function can expose associated interfaces; HIDMaestro's standard Xbox 360 profile implements a real system-discoverable XUSB interface in UMDF2. The missing work is a physical USB application, protocol/lifecycle integration, and qualification of installation and full-path behavior on ordinary Windows.

This is stronger than merely finding unrelated components: sections below trace input, reverse rumble and keyboard paths, identify their formats and ownership, and list the unverified transitions. It is not evidence that the complete replacement already works. No raw Chatpad report was read by a new user-mode transport in C1.

`XUSB_PRESERVING_USERMODE_FEASIBLE` is **not established**: healthy xusb22 publishes working handles but no demonstrated generic endpoint-zero/interface-2 transport. `CUSTOM_KERNEL_DRIVER_STILL_REQUIRED` is too broad for the newly permitted whole-device alternative. `THIRD_PARTY_SIGNED_VIRTUAL_BUS_REQUIRED` is not a necessary condition for standard HIDMaestro UMDF2, although it applies to a ViGEm/USB-IP implementation.

Recommend a bounded WinUSB + HIDMaestro `xbox-360-wired` experiment before choosing the production architecture. Retain the current filter as the working reference. Do not migrate production based on README latency or signing claims. See [the exact staged experiment and rollback](CHATPAD-WHOLE-DEVICE-EXPERIMENT.md).

## A. Verified healthy baseline

| Observation | Code 52 baseline, TASK 8L | C1 after operator's TESTSIGNING reboot |
|---|---|---|
| Package | Extension oem104.inf, 1.0.14.0 | Same extension; base xusb22.inf 10.0.26100.9278 |
| Physical status | Code 52, 0xC0000428 | OK / problem 0; IG_00, HID and VHF subtree OK |
| Actual stack | USBHUB3 only | xusb22 → ChatpadFilter → vhf → USBHUB3 |
| Services | xusb22/ChatpadFilter/vhf stopped | All three running |
| Installed filter image | Matches retained 1.0.14 | Same SHA-256 `16151F574AB93BEA556B08623D8450E48AF5F3308FA82E40FD5CFADBBA76E8C0` |
| Configuration / open pipes | 0 / 0 | 1 / 7 |
| XInput | 1167 in all four slots | Slot 0 succeeds, other slots 1167; motion capture contains 89 states (initial + 88 transitions), zero error records; user confirms real input |
| MS OS string EE | Query failed 31; cached osvc 01 90 | MSFT100, vendor request 90 readable |

`NtQuerySystemInformation(SystemCodeIntegrityInformation)` succeeded with options `0x00283603`: TESTSIGN and HVCI-enabled flags set. This verifies effective code-integrity state; it is not a successful BCD query. `bcdedit /enum '{current}'` failed parameter parsing and plain `/enum` returned access denied. No BCD/security setting was changed. This boot cannot demonstrate non-TESTSIGNING installation or Secure Boot acceptance. [Microsoft CI flags](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntquerysysteminformation).

`services-before.json`, `pnp-stack.txt`, `subtree.json`, `filter-hash.json`, `code-integrity.json`, `hub-descriptors.json`, `xinput.json`, and `xinput-motion.json` preserve the evidence. The hash identifies the installed service image; this is not an in-memory executable-page hash. VHF keyboard presence is the existing filter's output. C1 did not separately exercise the complete Chatpad key/layer matrix.

## B. Healthy user-mode interface census

CM enumeration across registered interface classes and an independent SetupAPI enumeration agree on **seven active links** in the target subtree; `setupapi-cm-diff.txt` is empty. `subtree-interface-opens.json` contains exact paths, access masks and errors. Access columns below are zero, GENERIC_READ, GENERIC_WRITE, and READ|WRITE. All attempts use share READ|WRITE, OPEN_EXISTING and FILE_FLAG_OVERLAPPED from an ordinary-user process. `0` means successful open; `5` is access denied; `2` is path not found.

| Node / interface GUID | 0 / R / W / RW | Meaning |
|---|---|---|
| Physical custom control `{63b66b53-8aae-4f7d-919b-7e1a4f167a04}` | 0 / 0 / 0 / 0 | Published by our filter; not independent transport |
| Physical USB `{a5dcbf10-6530-11d2-901f-00c04fb951ed}` | 0 / 0 / 0 / 0 | USB identity handle, not proof of raw pipe access |
| Physical XUSB `{ec87f1e3-c13b-4100-b5f7-8b84d54260cb}` | 0 / 0 / 0 / 0 | Working XInput stack |
| IG_00 gamepad HID `{4d1e55b2-f16f-11cf-88cb-001111000030}` | 0 / 0 / 0 / 0 | Parsed gamepad HID |
| IG_00 additional `{f3b4c28a-53e3-48dc-9c2b-f99db893cdff}` | 0 / 0 / 0 / 0 | Additional published interface; no raw Chatpad contract identified |
| VHF keyboard HID `{4d1e55b2-f16f-11cf-88cb-001111000030}` | 0 / 5 / 0 / 5 | Existing filter-generated keyboard |
| Keyboard class `{884b96c3-56ef-11d1-bc8c-00a0c91405dd}` | 0 / 5 / 0 / 5 | Same keyboard's class interface |
| Historical disabled IG_02 HID, not in active seven | 2 / 2 / 2 / 2 | Remains stale |

Original `artifacts/task-8l/interface-opens.json` had no active target link and only the stale IG_02 failure. C1 `interface-opens.json` repeats that VID-based census; the subtree census additionally finds the VHF identity, whose path does not carry the physical VID/PID.

`HidD_GetPreparsedData` / `HidP_GetCaps` succeed: gamepad UsagePage 1 / Usage 5, input 15 bytes, output/feature 0; VHF keyboard Page 1 / Usage 6, input 9, output/feature 0. Neither is the five-byte interface-2 wire stream. `WinUsb_Initialize` on successfully opened USB and XUSB RW handles fails **87**. WinUSB APIs need their corresponding driver stack; a generic USB interface handle is insufficient. [Initialize contract](https://learn.microsoft.com/en-us/windows/win32/api/winusb/nf-winusb-winusb_initialize).

Only identified read-only operations were attempted. No private IOCTL search, raw concurrent pipe reader or activation request was sent. XInputGetState proves decoded controller access, not endpoint-zero or Chatpad access. Thus no useful direct Chatpad path through healthy xusb22 was demonstrated. This is still a **filter-containing** sample; a healthy Microsoft-only sample is not available, and no universal impossibility claim is warranted.

Separate defect: retained `ChatpadControl.exe status` and `diagnostics` both open the interface but return Win32 87 / exit 4. Source sends the expected zero-input/read-output IOCTLs; the lower filter publishes its interface on the physical stack. A possible explanation is top-of-stack xusb22 rejecting private IOCTLs before they reach the lower filter, but no trace proves that cause. Treat live control/configuration acceptance as FAILED, independent of working game input. A sideband/control-device correction would be a separate task; no fix was made.

## C. Whole-device WinUSB transport

Live descriptors are unchanged across boots: USB 2.0 descriptor, device class/subclass/protocol FF/FF/FF, VID 045E / PID 028E, bcdDevice 0114, endpoint-zero max packet 8, one configuration (value 1), total length 153. All four interfaces have alternate setting 0; no additional alternate setting or IAD appears. The actual connection is full speed. All seven nonzero endpoints are interrupt, max packet 32.

| Interface | Class/subclass/protocol | Endpoint / direction / bInterval | Role supported by source |
|---|---|---|---|
| 0 | FF/5D/01 | 81 IN / 4; 01 OUT / 8 | Controller reports; rumble and player LED output |
| 1 | FF/5D/03 | 82 IN / 2; 02 OUT / 4; 83 IN / 64; 03 OUT / 16 | Accessory/headset transport; not implemented by proposed initial bridge |
| 2 | FF/5D/02 | 84 IN / 16 | Chatpad five-byte messages |
| 3 | FF/FD/13 | None | Vendor identity/security function; no data pipe |

No usbccgp-created `MI_02` child exists. Whole-device ownership does not require one: bind a function INF to `USB\VID_045E&PID_028E`, open its new interface, call `WinUsb_Initialize`, then obtain associated interfaces. Expected default is IF0 and associated indexes 0/1/2 correspond to IF1/IF2/IF3; verify each returned `bInterfaceNumber` with QueryInterfaceSettings. Index 1 is **not** alternate setting 1. No SetCurrentAlternateSetting(1) is justified. [Associated-interface contract](https://learn.microsoft.com/en-us/windows/win32/api/winusb/nf-winusb-winusb_getassociatedinterface), [WinUSB architecture](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-architecture).

ReadPipe on IF0/81 and IF2/84, WritePipe on IF0/01, and ControlTransfer on endpoint zero form the physical path. Device-recipient vendor requests (40/C0) use the default handle. Interface-recipient 41 commands use the IF2 handle; WinUSB sets the low interface byte of wIndex from that handle. Keep device-recipient magic indexes such as E416 intact. [ControlTransfer contract](https://learn.microsoft.com/en-us/windows/win32/api/winusb/nf-winusb-winusb_controltransfer).

This predicts access to the complete required configuration after replacement; it has not been measured on this controller under WinUSB. The existing initialization failure under xusb22 does not refute a different binding. Loss of physical XInput is expected and intentional while bound to WinUSB.

### Concrete protocol paths

1. **Controller → XInput.** IF0/81 supplies the wired 20-byte controller packet (`00 14`), within a 32-byte endpoint buffer. Bytes 2–3 carry D-pad, Start/Back, stick clicks, bumpers, Guide and ABXY; bytes 4–5 are independent unsigned triggers; bytes 6/8/10/12 start signed LE16 sticks. Reject/route other packet types rather than interpreting every completion as input. Convert to HMGamepadState (normalized axes, buttons and hat), SubmitState → shared memory/doorbell → HMXInput UMDF companion → system xinput1_4 XInputGetState → game. Preserve independent triggers and exact neutral/extreme behavior; do not copy Linux uinput Y inversion blindly. Guide exists in the physical packet and backend encoding, but ordinary documented XInputGetState does not promise a Guide bit; test Guide-aware consumers separately.
2. **XInput rumble → physical motors.** XInputSetState → companion IOCTL_XUSB_SET_STATE → output ring → SDK OutputReceived → application parser → WinUSB IF0/01. Typical XUSB callback packet uses motor bytes 2/3; validate source and length and capture actual callback before enabling output, rather than treating its header as the USB header. Physical packet is `00 08 00 <left> <right> 00 00 00`. Physical LED packet is `01 03 <pattern>`; virtual slot assignment does not automatically select a physical player LED. Start/stop commands and loss handling require explicit application policy.
3. **Chatpad → keyboard.** After independently establishing controller readiness, use the six existing requests in `src/protocol/ChatpadProtocol/ChatpadActivationRequests.c`: `(40,A9,A30C,4423,0)`, `(40,A9,2344,7F03,0)`, `(40,A9,5839,6832,0)`, `(C0,A1,0,E416,2)`, `(40,A1,0,E416,2; 09 00)`, `(C0,A1,0,E416,2)`. Tuple fields are request type, request, value, index, length, in hex. Preserve existing ordering and narrowly accepted stalls; Win32 failures do not expose the same USBD status contract as the kernel, so error translation remains work. Current driver gates activation on completed xusb22 input; replacement must prove equivalent physical readiness itself.
4. Start IF2/84 input and the existing alternating zero-length `(41,00,001F,0002,0)` / `001E` keepalive schedule. After the first complete packet, issue `001B` once, as in the working 1.0.13/1.0.14 implementation. A first `F0` status is not a key. Require real five-byte type-00 press/release packets, then reuse the repository's portable Base/Green/Orange decoder/mapper semantics. Translate held-state transitions to scan-code SendInput with explicit key-up tracking. `001B` has observed key-data-enable behavior and historical backlight naming; arbitrary brightness/backlight-off parity is not proven.

Controller wire formats and a user-space combined controller/Chatpad implementation were inspected in [xboxdrv, pinned 0705fa1, controller source](https://github.com/xboxdrv/xboxdrv/blob/0705fa16c8b8be30212d7e824cb0ad6fec60b2b4/src/controller/xbox360_controller.cpp) and [Chatpad source](https://github.com/xboxdrv/xboxdrv/blob/0705fa16c8b8be30212d7e824cb0ad6fec60b2b4/src/chatpad.cpp). That is Linux/libusb evidence, not a Windows run. Its GPL-3.0-or-later code must not be copied into this MIT implementation; retain independently implemented protocol knowledge and our existing parser. Its newer broad STALL continuation is not adopted.

SendInput is an interactive-session keyboard path with UIPI restrictions, not a system VHF keyboard. Elevated targets, secure desktop, locked sessions, application crashes and stuck modifiers need separate treatment. A privileged virtual-controller helper does not justify running every keyboard-injection component elevated. [Microsoft SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput).

### Lifecycle obligations

| Event | Required bridge behavior / remaining evidence |
|---|---|
| Unplug/replug or port change | Cancel overlapped requests, neutralize/dispose virtual controller, release injected held keys, close handles; rediscover by interface + physical identity, never cached path; open/reinitialize once per arrival |
| Application restart/crash | Exclusive physical owner; no duplicate virtual slot or stale state; external/session watchdog needed where process death prevents key-up/motor-stop; SDK orphan cleanup alone is not a complete fail-safe |
| Windows reboot | WinUSB binding persists but no useful controller input exists until bridge starts; verify startup ordering, session and privilege split |
| Sleep/idle/resume | Handle request cancellation/device restart; re-establish readiness and activation without duplicate readers; qualify with default power policy before proposing any change |
| Multiple controllers | Per-device protocol and held-key state, deterministic virtual identity, four-slot XInput limit and slot reassignment; baseline experiment uses one physical target |
| Headset/accessories | IF1 becomes application-owned too; audio/headset fidelity is outside initial experiment and must be an explicit production limitation |

## D. Binding and signing requirements

The proposed binding package contains **our INF + signed CAT**, with `Include=winusb.inf`, `Needs=WINUSB.NT` and corresponding Services section, USBDevice class, a new DeviceInterfaceGUIDs value, AMD64 model `USB\VID_045E&PID_028E`, and no custom SYS/coinstaller. It must not target MI_02 or add ChatpadFilter/VHF. The exact draft contract is in the experiment document; no INF/CAT was generated or installed. [Microsoft WinUSB package instructions](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation).

| Component | Installation / trust | Kernel-signing implication |
|---|---|---|
| Inbox winusb.sys | Supplied/signed by Microsoft | No newly authored kernel binary to submit |
| Our WinUSB INF/CAT | Admin install; signed catalog, trusted signer/chain; local test signer in LocalMachine Root and TrustedPublisher for internal testing | Catalog installation policy still applies; inbox SYS does not make arbitrary unsigned INF trusted |
| HIDMaestro standard profile | Custom signed UMDF DLLs and two catalogs; admin install/creation; current installer creates machine-local signing certificate/trust | No vendor kernel SYS in this profile; custom user-mode drivers still installed |
| ViGEm or USB/IP backend | Third-party kernel package and accepted kernel signatures | Dependency on vendor's signed kernel bus remains |
| Our application / managed helper | Executables, SDK/runtime and installer; release code signing desirable, privilege/session design required | No kernel-driver submission for application code |
| Current ChatpadFilter | Our SYS + Extension INF/CAT | Production kernel signing/qualification still required; local certificate alone did not prevent Code 52 in normal boot |

**Can a self-trusted CAT suffice without TESTSIGNING?** Our inference from the separate Microsoft policies is that, on an ordinary AMD64 desktop, a correctly trusted local catalog can satisfy installation of an INF referencing an already Microsoft-signed inbox binary; it does not need to authorize a new kernel binary. This is the relevant distinction, not an exemption from all driver signing. Microsoft's PnP documentation separates package trust from kernel-image loading, and certificate documentation requires machine stores. Local self-trust is an internal deployment mechanism; public release normally uses a release/WHQL signing route, with edition/architecture/enterprise-policy restrictions. S mode and ARM64 are not covered by this local AMD64 conclusion. **This exact package's normal-boot acceptance remains UNTESTED.** [PnP policy](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/pnp-device-installation-signing-requirements--windows-vista-and-later-), [test-certificate installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/installing-test-certificates), [kernel signing policy](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-policy--windows-vista-and-later-).

UMDF2-only packages similarly do not introduce a new vendor kernel image. This does not waive UMDF package/DLL trust or device-class-specific rules, nor prove Secure Boot/HVCI acceptance. Do not disable those protections to turn a failed production qualification into a pass.

## E. HIDMaestro source audit

Pinned [commit 1c126ed4780322454391b7be782230b35b0810f6](https://github.com/hifihedgehog/HIDMaestro/tree/1c126ed4780322454391b7be782230b35b0810f6), master, 2026-10-03; [release v1.10.1](https://github.com/hifihedgehog/HIDMaestro/releases/tag/v1.10.1) same day. Active, not archived; MIT for core. Bundled USB/IP has its own license. Local detailed audit: `artifacts/task-8lc1/hidmaestro-audit.md`.

| Question | Source-backed finding |
|---|---|
| Driver composition | `driver/hidmaestro.inf` loads HIDMaestro.dll with inbox mshidumdf.sys/WUDFRd.sys; `driver/hidmaestro_xusb.inf` loads HMXInput.dll as companion. Standard `profiles/microsoft/xbox-360-wired.json` uses this UMDF2 route. Composite USB personas use a separate third-party USB/IP kernel backend and must not be substituted. |
| Genuine XInput | `ControllerProfile.cs` selects the companion; DeviceOrchestrator creates its SWD identity; INF and companion.c register GUID_DEVINTERFACE_XUSB. HMController.SubmitState builds separate trigger/button/stick state; SharedMemoryIO writes seqlock state and signals; companion.c decodes it and implements GET_STATE's 29-byte reply, information and capabilities. System xinput1_4 discovers it; no per-game DLL replacement. |
| Feedback | companion.c:840–893 publishes SET_STATE bytes as source XInput to a 64-slot shared output ring; HMController.cs:1202–1218 drains it into OutputReceived. Consumer must copy callback data before retaining it (reused backing buffer). Overflow can drop old packets. Our application must implement physical rumble/LED translation; HIDMaestro does not talk to this WinUSB controller. |
| Install | HMContext requires admin for install and controller creation. DriverBuilder creates a machine-local self-signed certificate, imports My/Root/TrustedPublisher, signs DLLs/CATs and invokes pnputil. InstallDriver can remove other HIDMaestro virtual devices during cleanup; not an innocent read-only availability check. |
| Normal security | Upstream reports Windows 11 26200 / Windows 10 19044 without TESTSIGNING. Source supports plausibility; no adequate Secure Boot/HVCI acceptance evidence for this host. Both remain UNTESTED here. |
| Latency | Event-driven state and output; upstream virtual SubmitState→XInput runs report approximately 32–38 microseconds median, with a later run around 49. These exclude physical USB polling, our parser/IPC, game polling and rendering. No local bridge latency measured. Output's ~0.15 ms benchmark is DS4 HID-write→callback, not physical Xbox rumble. |
| Lifecycle | Dispose, SWD teardown, orphan cleanup and repeated create/swap tests exist; not proof of physical WinUSB recovery. Startup cleanup can affect other consumers. No immediate crash safety guarantee for injected keys or motor state. |
| Native SDK | Public SDK is C# targeting net10.0-windows10.0.26100.0; no supported C/C++ consumer ABI found. Use a small managed helper/IPC or .NET hosting; privately reproducing shared-memory/registry/lifecycle contracts would increase maintenance. |

Key implementation references: [UMDF HID INF](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/driver/hidmaestro.inf), [XUSB INF](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/driver/hidmaestro_xusb.inf), [companion implementation](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/driver/companion.c), [SDK controller](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/sdk/HIDMaestro.Core/HMController.cs), [installer](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/sdk/HIDMaestro.Core/Internal/DriverBuilder.cs).

Tests inspected include `xbox_dpad_xinput_check`, `xbox_combined_trigger_check`, `xusb_wgi_single_check`, `dispose_orphan_check`, `foreign_devnode_survival_check`, `test/Latency.cs` and output benchmark source. The release reports 64/64 upstream scenarios; **none was executed locally** because installation is prohibited. Some probes install drivers themselves. The latency harness picks the first connected XInput slot, ignores a return code in its polling loop and returns zero even with timeouts; a future run must verify identity, success codes, counts and timeout totals independently.

WGI/GameInput fidelity is a separate gate. Current INF uses an `xinputhid` filter-string classifier workaround and companion implements reverse-engineered XUSB/WGI replies. Current WGI duplicate-controller test verifies exactly one entity across creation cycles and checks that HID buttons remain correct. Historical `BRANCH_STATUS.md` records an archived rumble dead end, not current master's final result. Neither that stale failure nor current fixes justify claiming complete GameInput parity. Test XInput, WGI and GameInput separately after Windows updates. [Current WGI probe](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/test/probes/xusb_wgi_single_check/Program.cs), [latency methodology](https://github.com/hifihedgehog/HIDMaestro/blob/1c126ed4780322454391b7be782230b35b0810f6/docs/testing/latency.md).

## F. Other virtual-controller choices

| Backend | Current evidence and limitation | Decision |
|---|---|---|
| ViGEmBus | BSD-3-Clause; archived/retired 2023-11-02, final setup 1.22.0 removes updater without refreshing driver. Real virtual Xbox kernel bus. Downloaded installer Authenticode valid; this does not verify contained driver's present Windows 11/HVCI acceptance or function. No installation here. | Compatibility reference; cannot promise existing release works on every current build, vulnerable-driver policy or game. Abandoned kernel dependency is a production risk. |
| VIIPER + usbip-win2 | Active releases v0.8.2 (2026-09-30) and v0.9.8.1 (2026-09-27). Virtual USB Xbox with real host XInput through kernel USB/IP transport. VIIPER server/core GPL, client libraries MIT; in-process linking has different licensing implications from TCP client. Installation docs describe importing a test CA; latest package internals were not qualified. | Maintained alternative, but adds third-party kernel transport and deployment/licensing complexity. Not a kernel-free answer. |
| LizardByte/libvirtualhid | Active v2026.914.1218.10: AMD64 UMDF2 Xbox path with broker, inbox kernel participants. C++ library MIT; Windows driver/broker/package LB-SAL-1.0, machine license activation required. CI signs DLL/EXE/CAT; downloaded MSI Authenticode valid. | Native-facing UMDF alternative worth evaluating if its commercial/source-available terms fit; no local license/install/runtime qualification. |
| cgutman/WinUHid | MIT, generic UMDF virtual HID, not archived; no released ready Xbox/XUSB personality established by this research. | Building block, not a drop-in proven XInput backend. |
| Per-game XInput wrappers | Replace/hook one game's DLL behavior rather than publish system controller. | Only a game-specific fallback; excluded from the main architecture. |

Primary references: [ViGEm end of life](https://docs.nefarius.at/projects/ViGEm/End-of-Life/), [ViGEm 1.22.0](https://github.com/nefarius/ViGEmBus/releases/tag/v1.22.0), [VIIPER Xbox source documentation](https://github.com/Alia5/VIIPER/blob/3111299d67bacbaa7f6a31d56ea9ae06678f5865/docs/devices/xbox360.md), [VIIPER installation](https://github.com/Alia5/VIIPER/blob/3111299d67bacbaa7f6a31d56ea9ae06678f5865/docs/getting-started/installation.md), [usbip-win2 releases](https://github.com/vadimgrn/usbip-win2/releases), [libvirtualhid Windows architecture](https://github.com/LizardByte/libvirtualhid/blob/dc57a03569025304df8d85615febd508ad29b7de/docs/windows-driver.md), [license map](https://github.com/LizardByte/libvirtualhid/blob/dc57a03569025304df8d85615febd508ad29b7de/LICENSES/license-map.md), [WinUHid](https://github.com/cgutman/WinUHid).

Downloaded, never executed: ViGEm installer SHA-256 `89220A7865076B342892F98865F3499FB7C4CFD673159E89D352C360FD014C6A`; libvirtualhid MSI `BC31539A41F71939C13DECB171CCBD4306FAE1FED63273434A4F5CECCAF3E71C`. `backend-reference/installer-signature-evidence.json` records **installer-only** signatures, not CAT membership or kernel load verification.

## G. Production comparison and remaining gates

| Dimension | A: xusb22 + our filter + VHF | B: WinUSB + application + UMDF virtual X360 + SendInput |
|---|---|---|
| Controller compatibility | Retains Microsoft physical XInput and accessory behavior | Must reproduce state/output/lifecycle; virtual identity/anti-cheat/GameInput compatibility requires testing; headset omitted initially |
| Signing | Our kernel SYS requires production route | Inbox physical SYS; our binding CAT and third-party UMDF package still require trust/install; ordinary-boot proof pending |
| Maintenance | Kernel safety, WDF/USB coexistence and VHF; control IOCTL defect outstanding | USB decoder, process/session/IPC/watchdog and virtual SDK dependencies; undocumented XUSB behavior upstream |
| Rumble/LED | Native xusb22 retains handling | Explicit output translation, serialization, stop policy and slot/LED mapping |
| Latency | Existing native controller path | Adds scheduling/parser/virtual path; no physical end-to-end measurement yet |
| Failure mode | Filter failure can prevent physical device starting (observed Code 52) | Missing/crashed bridge can remove all controller/Chatpad function until recovery; input release must be designed |
| Keyboard | System VHF keyboard | Session/integrity-limited SendInput, different secure/elevated desktop behavior |
| Proven here | Healthy physical XInput with exact loaded 1.0.14; historical Chatpad implementation | Descriptor/source chain and experiment design only |

The justified next action is the staged prototype in the companion plan. Qualification must prove installation with TESTSIGNING off, all real controls, reverse physical rumble, actual five-byte Chatpad transport independent of keyboard injection, mapped press/release, unplug/restart/sleep recovery, measured added latency, no duplicate virtuals, and restoration of the original stack. Secure Boot and HVCI require a suitable unchanged-policy environment. Until then B is a credible development direction, not a production replacement.

No driver was built, signed, packaged, installed, removed or rebound in C1. No certificate/trust, BCD, Secure Boot, HVCI or power setting was changed; no reboot, virtual-controller installation, raw pipe activation/read or SendInput demonstration was performed. Only existing loaded drivers answered documented/read-only diagnostic operations. Product and legacy sources are unchanged.
