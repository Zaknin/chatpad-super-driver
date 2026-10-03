# Whole-device WinUSB package trust

TASK 8L-C2R1, Microsoft documentation checked 2026-10-03. This conclusion applies
to the reviewed x64 Windows 11 INF/CAT-only package. It does not apply to the
Chatpad KMDF filter or the separate HIDMaestro kernel package.

The candidate is expected to stage and bind on this local machine in ordinary
Windows with TESTSIGNING disabled: its existing local certificate is already
trusted for PnP, and it references Microsoft's independently signed inbox
`winusb.sys`. This is an installation expectation based on documented policy and
offline verification, **not a verified installation**. C2R1 did not stage,
bind, restart, create devices, or change trust/security settings.

## Ten signing questions

| Question | Answer for this package |
| --- | --- |
| 1. Build | WDK InfVerif checks INF syntax; Inf2Cat checks signability and emits an unsigned catalog. Building needs neither a trusted signer nor device installation. [Inf2Cat](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/inf2cat) |
| 2. Stage | The package must have valid INF syntax, all required material, catalog member hashes, trusted catalog signature, and an authorized installer. Staging is distinct from binding a device. [Driver Store](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/driver-store) |
| 3. Bind locally | After valid staging, select the exact intended driver node for the physical instance; PnP must accept its package signature, and the actual function driver's binary must satisfy kernel code-integrity policy. These are separate checks. [PnP signing](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/pnp-device-installation-signing-requirements--windows-vista-and-later-) |
| 4. TESTSIGNING disabled | The local INF/CAT introduces no new kernel executable. Microsoft's signed inbox binary is loaded. TESTSIGNING enables test-signed kernel code. For this candidate, normal-mode installation is an expectation inferred from the separately documented package/binary policy and actual offline results below. [Loading test-signed code](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/the-testsigning-boot-configuration-option) |
| 5. Secure Boot | Secure Boot strengthens kernel signing policy and protects boot configuration. It does not turn a local certificate into a Microsoft kernel signer. Here no third-party kernel image is introduced; verify the inbox image separately. This is a policy inference, with actual binding still untested. [Driver signing policy](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-policy--windows-vista-and-later-) |
| 6. HVCI | Memory Integrity validates executable kernel pages in VBS and imposes binary compatibility requirements. A local CAT signature cannot establish HVCI compatibility. The candidate references the installed Microsoft binary; no custom binary is supplied. Current HVCI is enabled. Physical C3 acceptance remains untested. [Memory integrity](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/device-guard-and-credential-guard) |
| 7. Local self-signed CAT | Yes, it is expected to satisfy local PnP installation trust for this INF/CAT-only internal experiment when the signer is trusted on the local machine and exact INF membership is valid. It cannot authorize third-party kernel code in ordinary boot. This limited expectation combines Microsoft's internal trusted-publisher guidance with the separate binary policy. [Trusted Publishers](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/trusted-publishers-certificate-store) |
| 8. Stores/actions | For an internal self-signed identity, its public certificate must establish the LocalMachine Root chain and be in LocalMachine TrustedPublisher for PnP silent installation. A private key is needed only on the signing machine's My store. All required public trust entries already exist here; **no certificate installation is needed or performed in C2R1**. Stage and exact bind are future authorized actions. On a fresh machine, deliberate public-certificate imports into those two machine stores would be separate security changes, outside this task. [Installing test certificates](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/installing-test-certificates), [Trusted Publishers](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/trusted-publishers-certificate-store) |
| 9. Production | The local certificate is not production distribution trust. For release, obtain a WHQL/Hardware Dashboard signature when applicable; ordinary new third-party kernel binaries need Microsoft's Dev Portal signature. Microsoft's universal WinUSB INF example is eligible for Hardware Dashboard signing. This task neither submits nor certifies the package. [Driver signing policy](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-policy--windows-vista-and-later-), [WinUSB installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation) |
| 10. Inbox alternative | Automatic inbox matching requires firmware's WINUSB Microsoft OS descriptor. Microsoft also documents manually selecting **Universal Serial Bus devices / WinUsb Device**, adding the instance's device-interface GUID, and reconnecting. Thus a supported manual inbox route exists without a custom catalog even without automatic descriptors. It entails live instance/registry/reconnect changes and is not implemented or attempted here. The custom exact-HWID package remains the prevalidated scripted C3 route. [WinUSB installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation), [WinUSB device](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/automatic-installation-of-winusb) |

## Actual offline variants and verification

Run the source-controlled builder only for offline preparation:

```powershell
tools/Build-ChatpadWinUsbVariants.ps1 -SecurityEvidencePath artifacts/task-8lc2r1/security-state.json
```

The default output is `artifacts/task-8lc2r1/trust-final/`. It refuses an existing
output directory, signs only the new candidate CAT using the exact authorized
existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`, and never creates or
exports certificates/private keys. It does not import certificates or stage a
package. Signed output has no timestamp; use while the existing certificate is
valid and recheck trust immediately before C3.

The unsigned variant preserves the exact accepted C2 bytes:

- INF SHA256 `F66F99B466535A3E693354BE62B0EC75EA466DF4E4C612B72C3AB8AAAB912B17`.
- CAT SHA256 `35DF7AA9E125C9507F463C0BBEFA828828849FAD60970A199BC865C00B668EB7`.

Fresh InfVerif/Inf2Cat signability validation passes separately. Experimental
rebuild comparison failed because Inf2Cat emits a random CTL ListIdentifier and
current ThisUpdate; the failure and decoded catalog are retained. No generated
ASN data was manually changed. The frozen unsigned payload and later archive
can be reproduced from the preserved exact bytes; a fresh Inf2Cat invocation is
not claimed byte reproducible.

For the local signed variant, offline SignTool results are:

- CAT `verify /pa /v`: exit 0.
- Exact INF `verify /pa /v /c CAT INF`: exit 0.
- CAT and INF-member `verify /kp`: exit 1, certificate does not chain to a
  Microsoft root. This diagnostic is retained, not hidden as a pass.
- Installed Microsoft `winusb.sys` `verify /a /kp /v`: exit 0.
- Unsigned CAT `verify /pa /v`: exit 1 as expected.

The local catalog `/kp` failure means it cannot vouch for a new executable kernel
binary. It does not invalidate the separate PnP Authenticode trust result for a
package that supplies no kernel binary. This follows Microsoft's explicit
distinction: a package catalog must additionally meet kernel policy when it is
needed to verify an executable lacking an embedded signature.
[PnP signing](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/pnp-device-installation-signing-requirements--windows-vista-and-later-).

Cryptographic CMS signature, exact signer, local-machine chain and Root/publisher
presence also pass. The machine-chain check is offline and does not check
revocation. Hashes, exact commands, exit codes, captured normal-mode state and
decision are in `trust-report.json`; `trust-decision.json` explicitly records
`PhysicalInstallVerified=false` and `ProductionDistributionApproved=false`.

## Readiness decision and limits

`Get-ChatpadWinUsbTrustDecision` in `tools/ChatpadWinUsbTrust.psm1` requires every
boolean prerequisite explicitly; missing or malformed evidence blocks. It
requires reviewed exact INF identity, an exclusively inbox package, intact
exact signer, CAT Authenticode plus INF membership, machine Root/publisher/chain,
inbox kernel-policy verification, and effective normal code-integrity mode.
It does not reinterpret a local catalog `/kp` failure as a pass.

Focused tests cover each missing prerequisite, malformed/missing evidence,
catalog-versus-binary policy separation, exact hash validation, missing files and
tampering. Enterprise application-control policy, future revocation/expiry,
actual SetupAPI installation behavior, composite ownership and hardware
functionality are not proved by these checks. C3 must reread trust and identities
before mutation, retain SetupAPI error evidence, and restore on failure.

The separate optional Chatpad filter is still test-signed kernel code and may
remain Code52 in ordinary boot. Installing its old locally trusted catalog does
not make its SYS loadable with TESTSIGNING disabled. Microsoft Xbox base recovery
must succeed independently; optional filter restoration is not a claim that the
filter runs under this security policy.
