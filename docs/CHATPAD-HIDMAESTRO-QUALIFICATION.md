# Pinned HIDMaestro runtime qualification — TASK 8L-C2R2

2026-10-04. Verdict **BLOCKED**, not C3_READY. Exact revision `1c126ed4780322454391b7be782230b35b0810f6`, tag `v1.10.1`. No installation, driver signing, revision substitution or SDK context creation.

## Exact dependency

Official archive SHA256 `DE5D0569F94229935523FA34F00136F597809F2E7760B783EDBCDD0258E145DC`; external SDK SHA256 `CA45EFE79C2406EB766C972F9DFEBC4BA80E33E95923D2DF4B49B8F470434E75`. Clean pinned checkout/tag and prepared archive/SDK hashes were independently verified.

The `xbox-360-wired` profile needs both main virtual HID and XUSB companion packages, not USBIP. Their INFs target x64/root devices and UMDF 2.15.0. Main service HIDMaestro uses inbox mshidumdf.sys/WUDFRd.sys; companion HMXInput uses inbox WUDFRd.sys. Roots include root\HIDMaestro, root\HIDMaestroXUSB and root Xbox persona IDs; neither INF matches physical USB Xbox IDs. hmswd.exe is the software-device helper. Profiles are embedded in the managed SDK; .NET 10 Windows targeting is required.

Both release INFs have **DriverVer 10/03/2026,1.10.0.142**. DLLs/helper have **file version 1.10.1.0**, PE machine `0x8664` (x64). Source INF templates have another version; only stamped release bytes define this dependency.

| Required file | SHA256 |
| --- | --- |
| hidmaestro.inf | 00806FBAA52314C73EA895936D9FEBCD4925A22036B4E55C3DCDB3C794F61661 |
| HIDMaestro.dll | 24B23EB1F572A83B9785AAD8386B379ACE916A6B22AD0CAB054D43DEE5AD7090 |
| hidmaestro_xusb.inf | 7E98D5F3C7C757E40F4A50D15AD0ADF5DB4E15D6F415B34913AC2B054C65D76B |
| HMXInput.dll | B3760B79AFB98D2379AE29EE81B8C2B086F3635C426FDF42F0D34587EEE1B2E1 |
| hmswd.exe | 771A376DF3FA3BEDFEC9B8F7E31EA82AA379C16D0E87A0607AF1640AEF50723A |
| hidmaestro.cat / hidmaestro_xusb.cat | **Not supplied**; no hash, signer or membership verification available |

## Licensing and redistribution

Inspected literal pinned LICENSE (SHA256 `FBA8DB4FFF568AC6A91E4C3100D1BE32D83DAE713D924EECB291182FFC11D885`), driver/companion source headers, sdk/HIDMaestro.Core/THIRD-PARTY-NOTICES.txt, SDK resource-packaging project and driver/openvr/third_party/openvr/LICENSE. Headers reviewed contain no additional usage restriction. Release MIT license matches source after line-ending normalization.

HIDMaestro-authored material permits external runtime use, SDK/API consumption, binary/source redistribution and modification/forking under MIT with copyright/permission notices. Notices specify BSD-2-Clause for usbip-win2 and BSD-3-Clause for DsHidMini-derived material; OpenVR has its own BSD notice. Xbox qualification needs neither USBIP installation nor OpenVR registration.

The SDK embeds Microsoft signing/catalog tools copied from the WDK. The repository MIT grant does not establish redistribution rights for these Microsoft tools. No complete upstream SDK, release archive, runtime binary, embedded Microsoft tool or upstream source is included in the C2R2 public package. Our adapter assembly/apphost/configuration and notices are published, requiring a separately obtained pinned SDK. No upstream source is vendored into tracked files.

## Exact signing blocker

Installed signtool verify /pa /v returns **exit 1, No signature found** for HIDMaestro.dll, HMXInput.dll and hmswd.exe; Get-AuthenticodeSignature reports NotSigned. No CAT exists in archive/SDK resources. INF Authenticode UnknownError is not evidence of signing; membership requires its absent catalog.

Pinned Internal/DriverBuilder.cs defines HIDMaestroTestCert. EnsureTestCertificate creates/persists a key and adds its certificate to LocalMachine My, Root and TrustedPublisher. SignDrivers changes both DLLs; GenerateCatalogs creates/signs CATs; FullDeploy runs these before installation. The host has no HIDMaestroTestCert in these stores. Supported installation would therefore perform expressly prohibited trust changes. No lifecycle/signing helper is invoked; no certificate/private key is created/exported/imported.

UMDF architecture and inbox kernel components support ordinary Windows in principle; this supplied unsigned/no-CAT package is **not qualified**. Live HVCI/Secure Boot/load acceptance remains **UNTESTED**. TESTSIGNING=false and HVCI=true are verified before/after; Secure Boot query is inaccessible. This does not imply that UMDF requires TESTSIGNING or HIDMaestro inherently fails HVCI.

## Adapter and continuation

Real adapter Release compilation passes with zero warnings/errors. Read-only status is unavailable with contextConstructed=false and liveDeviceCreated=false. Initialization, virtual slot acquisition, live state submission/rumble and stale-device cleanup remain **BLOCKED/UNTESTED**. Offline guarded/mock lifecycle/state/rumble tests do not prove live functionality.

Runtime probe correctly rejects absent packages using exact raw embedded INF/DLL hashes. Upstream signing changes DLL bytes, so even upstream-signed installation cannot satisfy that raw DLL contract. Preserve validation; future authorized work needs independently frozen INF/CAT/signed-DLL/helper hashes and catalog membership/trust before installation/context construction. Do not accept arbitrary installed versions.

Reproduce with tools/Get-ChatpadHidMaestroQualification.ps1 -ReferenceRepository artifacts/task-8lc1/hidmaestro-reference (expected exit **2/BLOCKED**). It verifies source/tag/license/archive/SDK, reads metadata/resources and verifies signatures without upstream lifecycle calls or execution of extracted binaries. tools/Test-ChatpadHidMaestroQualification.ps1 tests synthetic missing/mismatched INF/CAT/DLL identities; identity alone never qualifies installation.

Before/after physical captures retain xusb22.inf/oem104.inf 1.0.14.0, Code 52/0xC0000428, exact identity/filter state. Raw serial/container/store inventories stay local. C3 preflight has exactly the missing-runtime blocker. No C3 transition.

Next: resolve a trusted signed runtime for this exact revision within unchanged security/trust constraints, pin signed bytes, then repeat C2R2 isolated live adapter/XInput/rumble/cleanup acceptance. If trust changes are necessary, a new human instruction must expressly authorize them. No newer revision/alternate backend.
