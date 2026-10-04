# Locally trusted HIDMaestro package — TASK8L-C2R3

Verified host result: normal Windows accepted and loaded the exact catalog-signed UMDF package with TESTSIGNING=false and HVCI=true. This is host-specific evidence, not an architecture assumption or universal signing-policy claim. C3 physical acceptance was not performed.

Source revision1c126ed4780322454391b7be782230b35b0810f6/v1.10.1, x64. SDK SHA256 CA45EFE79C2406EB766C972F9DFEBC4BA80E33E95923D2DF4B49B8F470434E75. INF1.10.0.142 and runtimeDLL1.10.1.0. Authored code MIT; SDK's embedded Microsoft tooling redistribution not established, so upstream/Microsoft binaries are omitted from publication.

Existing signer: CN=Chatpad Super Driver Local Development Test Signing, thumbprint885ADDC8018AC58E19B14668ACDAC9072BB6AE15. Public DER SHA256300238DB21F1ECD2F2C2E9F3A03EFF0147CBC419D474B1B3B89433569D5E6C96; exact public-only machine Root/TrustedPublisher copies and private signing key in CurrentUser/My. Valid2026-07-12 through2029-07-12, CodeSigningEKU1.3.6.1.5.5.7.3.3, current machine chain PASS. No trust/cert/key mutation or export.

| File | Frozen SHA256 |
| --- | --- |
| hidmaestro.inf | 92FEAC617024B5326F449B73EEF32516739F528190B7816CC2D81E7703F534FE |
| HIDMaestro.dll | 24B23EB1F572A83B9785AAD8386B379ACE916A6B22AD0CAB054D43DEE5AD7090 |
| hidmaestro.cat | 4BCCC6F0542033169EA5650BE7470E70DF80E38AA3F1DE596309E3BE935CCF20 |
| hidmaestro_xusb.inf | E4B26FAD873E6DDF6A6A3E8B43294C3ABFC953FA560EBAED2E8C4CF31A20115B |
| HMXInput.dll | B3760B79AFB98D2379AE29EE81B8C2B086F3635C426FDF42F0D34587EEE1B2E1 |
| hidmaestro_xusb.cat | C0E1EAFAB0D7014243F47AC1061B6B4D2AC425C15FA4E138FCBF57F34CE7EED8 |

Source INFs were UTF8/undecorated; initial InfVerif errors1003/1199 retained. Source packaging changes only encoding UTF16LE+BOM, CRLF and model OS floor NTamd64.10.0...17134. DLLs remain byte-identical unsigned release payloads. InfVerif/u and Inf2Cat pass; warnings2084 are inbox WUDFRd/mshidumdf service references. Both CATs SHA256-signed without timestamp, Authenticode Valid/exact signer, all4 required INF/DLL member verifications pass. Inbox kernel components pass /kp. CATs are frozen; fresh Inf2Cat generation is not byte deterministic. No generated ASN/catalog manual edits.

PnPUtil staged main as oem106.inf and companion as oem107.inf, exit0/no reboot. These OEM numbers are local addresses, not durable identity. Runtime guard pins content/catalog/signer/version. Xbox360 root models cannot match the physical USB target.

Real adapter qualification: one built-in xbox-360-wired profile, identity-key-owned ROOT main and SWD companion, mshidumdf and WUDFRd, both problem0 and two additional WUDFHost processes. Exactly one new XInput slot0. Neutral, A, B, diagonal Dpad, LT173/RT241, left/right stick extrema and final neutral all roundtrip exactly. XInputSetState32896/16448 returned0 and callback matched. Captured motor packet0000804002 required parser support for last byte02; historical fixture last00 remains accepted, unrelated LED/discovery packets rejected/logged. First run's parser rejection preserved as failure, not relabeled.

SDK context/creation uses only public APIs, no stock InstallDriver/FullDeploy. Qualified INF/CAT materialized through public DriverBuilder.EnsureExtracted before SDK binds it; extracted DLL hashes checked without modification. Existing GameInputSvc Running/Manual retained. SDK shared profile GameInput/OEM metadata had absent baseline; conflicts fail closed and temporary keys removed. Upstream ROOT/SWD index0 sweep conflicts also fail closed. Windows kept an SWD phantom after disposal: wrapper validates both exact active virtual IDs/owner token, removes only the recorded non-present SWD node and independently verifies absence. Initial security timestamp comparison failure fixed by comparing policy fields, preserving original failure; no security change occurred.

Physical invariant: original/final xusb22.inf10.0.26100.9278/oem104.inf1.0.14.0/Code52/0xC0000428, exact extensions/filters/class filters unchanged; arrival timestamp unchanged during virtual qualification. No physical restart/bind/USB/input/Chatpad/rumble operation. Root/Publisher/My inventories unchanged, TESTSIGNING=false/HVCI=true. Elevated SecureBoot=false observation and non-elevated query unavailable; no BCD/security/boot mutation.

Read-only C3 preflight PASS/C3Ready=true only after exact frozen runtime/current trust and hash-pinned isolated load/state/cleanup/invariant reports. Runtime qualification is not inferred from staging or catalog trust. Current component files/HEAD/Microsoft recovery/signatures are revalidated. C2R1 canonical proof remains within its existing scoped root; fresh C2R3 publication is verified separately.

Tests: one final comprehensive2056/2056, package33/33 and retained identity20/20, total2109 distinct automated checks PASS. Managed110/C3planning46 already included in comprehensive. Real8-state/rumble/cleanup evidence separate from offline test totals. Independent reviewer unavailable due account usage limit; local complete-diff review and source-side-effect checks performed.

Rollback prepared/identity-verified, not executed: after disposing/removing owned virtual devices and checking package hashes, administrator runs pnputil.exe /delete-driver oem107.inf /uninstall, then oem106.inf /uninstall. No /force or /reboot; stop on error/reboot required. Verify both OEM packages absent, no task virtual/slot, original physical/security/trust state unchanged. Physical Xbox recovery remains independent. Packages retained for C3.

Local artifacts: artifacts/task-8lc2r3. Canonical directory TASK-8L-C2R3/20261004T081603Z; actual result-manifest/receipt after commit/push records Git SHA, archive hash and independent readbacks. Raw serial/container/store inventories stay local; publication redacts private values and includes generated CATs, manifests, signatures, logs and own adapter/source only. Read receipts before treating publication complete.
