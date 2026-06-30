# Offline Inf2Cat Package Validation

## 1. Purpose and scope

This checkpoint records unsigned offline package closure for one exact
device-specific extension INF and one exact unsigned Release driver binary.
It proves that the two validated inputs can form the declared catalog package
for the selected Windows 11 x64 identifiers using the installed Inf2Cat
version.

This result is narrower than signing, trust, staging, installation, attachment,
or runtime validation. `InfVerif` proves static INF validity. `Inf2Cat` proves
offline package and catalog closure. Neither result proves package trust,
Windows acceptance, effective lower-filter placement, controller preservation,
or Chatpad behavior.

## 2. Repository checkpoint

- Source branch: `feature/offline-extension-inf-prototype`.
- Source commit: `9de526a55d5b60a28229cedc3a2e4e9926db6473`.
- Validation branch: `feature/offline-inf2cat-package-validation`.
- The validation changed no source code, INF, SYS, project, or tracked binary.
- No validation commit existed before this documentation-only checkpoint.
- Generated package and log evidence remained ignored beneath `artifacts/`.

## 3. Exact input identities

| Input | Repository-relative source | Size | SHA-256 | Authenticode |
| --- | --- | ---: | --- | --- |
| Extension INF | `prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf` | 1,636 bytes | `7E752EDAFDB252AF746C2AE6A9EFB3032A077A23FEB39C064D0E2C30700D11CE` | Not applicable |
| Release SYS | `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys` | 10,240 bytes | `00A9E8689114886C04B6C45E86603BE1257B42E6215B76CE41D3A721F28C5F6A` | `NotSigned` |

The copied package INF and SYS matched these source hashes exactly before and
after catalog generation.

## 4. Tool identity

- Historical executable:
  `C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x86\Inf2Cat.exe`.
- Windows Kits architecture directory: `x86`.
- File version: `1.0.0519.24`.
- Product version: `1.0.0519.24+3dc05997`.
- SHA-256:
  `B594728D38B271979367ABC8060A971B8E42422738009BE126710B1F5DD0FCBC`.

## 5. Exact execution

The retained command is:

```text
"C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x86\Inf2Cat.exe" /driver:"C:\Dev\chatpad-super-driver\artifacts\inf2cat-validation\20260629T220548Z\package" /os:10_CO_X64,10_NI_X64,10_GE_X64 /uselocaltime /verbose
```

- Selected Windows 11 x64 identifiers:
  `10_CO_X64,10_NI_X64,10_GE_X64`.
- `/uselocaltime` was used for DriverVer timestamp validation.
- Exit code: `0`.
- Warnings: none.
- Errors: none.
- `10_25H2_X64` was not advertised by the installed tool and was deliberately
  not passed.

## 6. Catalog result

- Ignored evidence package:
  `artifacts/inf2cat-validation/20260629T220548Z/package/`.
- Catalog filename: `ChatpadFilterExtension.cat`.
- Size: 1,262 bytes.
- SHA-256:
  `84CF148F8E04F41F3691B99B058BCDDE810B9EC99EB8DA4EF38DA53E11712B87`.
- Authenticode status: `NotSigned`.
- Container: PKCS#7 Certificate Trust List with four CTL entries.
- Members: `chatpadfilter.sys` and `chatpadfilterextension.inf`.
- Member digest algorithm: SHA-256.
- OS attributes: x64 Windows 11 21H2, 22H2, and 24H2.
- Hardware ID: `usb\vid_045e&pid_028e`.
- Signer material: no signer, recipient, embedded certificate, or CRL.

The final package manifest contained exactly the INF, SYS, and CAT.

## 7. Validation and audit results

- Prototype-INF validator: PASS.
- Repository safety before catalog generation: PASS.
- Repository safety after catalog generation: PASS.
- Offline Inf2Cat validation: PASS.
- Later independent read-only checkpoint review:
  **REVIEW PASS WITH FINDINGS**. See
  [Offline Inf2Cat Checkpoint Review](OFFLINE-INF2CAT-CHECKPOINT-REVIEW.md).
- The review found that the current files and retained evidence matched the
  recorded hashes, sizes, signatures, command, results, package manifest, and
  catalog structure.
- The review did not independently rerun historical Inf2Cat, InfVerif, or
  repository-safety execution.

This report is the authoritative record of the original package validation.
The linked checkpoint-review report records the later independent read-only
review. Neither report means Inf2Cat was rerun during documentation work.

## 8. Evidence limitations

Retained logs support the historical command, timing, output, and exit results,
but cannot provide the same assurance as an independently repeated run. Later
filesystem inspection also cannot prove absolutely that no historical file was
removed or retimestamped.

These are audit limitations, not package-validation failures. The retained
logs, current input and output identities, live catalog inspection, and clean
repository state were mutually consistent.

## 9. Proven conclusions

The exact validated extension INF and exact unsigned Release SYS successfully
form an unsigned catalog package for the Windows 11 x64 identifiers recognized
and selected from the installed Inf2Cat version.

`InfVerif` proves static INF validity. Inf2Cat proves offline package/catalog
closure for these exact inputs. The catalog remains unsigned and untrusted.

## 10. Explicitly unproven conclusions

This checkpoint does not prove:

- package signing or trust;
- Windows staging or acceptance;
- extension matching on the physical controller;
- lower-filter ordering beneath `xusb22`;
- preservation of ordinary controller operation;
- default-control-pipe visibility;
- Chatpad activation;
- Chatpad input;
- WDF request creation or submission;
- continuous input acquisition;
- keyboard output;
- reconnect, removal, power, or failure behavior;
- a usable production driver.

## 11. Safety record

The validation and independent audit did not:

- sign anything;
- create or import certificates;
- stage or install anything;
- mutate the Driver Store;
- modify services or the registry;
- load a driver;
- query or interact with the controller;
- commit or push generated evidence.

## 12. Evidence retention

Generated package files, the unsigned CAT, copied SYS, and logs remain beneath
ignored `artifacts/` directories. They are intentionally excluded from Git
history. This tracked report records identities and conclusions without
promoting generated evidence into source control.
