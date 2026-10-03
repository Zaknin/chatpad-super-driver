# Next Task

## Resolve exact signed HIDMaestro contract; repeat C2R2 before C3

Continue feature/chatpad-winusb-bridge-poc from committed C2R2 qualification/tooling, direct child of d2801b5c092025b800cd7536880c4103cd5320c7. Resolve exact SHA from Git and canonical C2R2 result manifest/receipt; require equality, clean status and origin 0/0. No task/chat is created automatically.

Current verdict BLOCKED. Revision 1c126ed4780322454391b7be782230b35b0810f6, release v1.10.1, stamped INF 1.10.0.142. Exact payload has unsigned UMDF DLLs/no CAT. Supported installer creates/trusts HIDMaestroTestCert and signs package; trust changes prohibited. Adapter expects unsigned embedded DLL bytes; signed bytes require independently pinned package contract, never weaker identity checks.

Physical target present with unchanged xusb22.inf/oem104.inf, expected Code 52; TESTSIGNING=false, HVCI=true. C2R1 absent-device state is historical. Release build passes; fresh comprehensive 2039/2039 and focused 20/20 pass. Runtime/live XInput/rumble/cleanup UNTESTED. Preflight has exactly one runtime blocker. After publication, independently verify the canonical receipt for actual archive/hash/readback/commit before continuation.

Next objective and preconditions:

1. Find a trusted signed runtime for this exact revision without security/trust changes. Do not substitute release or fabricate catalogs/signatures. If a trust change is necessary, obtain new explicit human authorization for that exact action; current instructions forbid it.
2. Once prerequisites are authorized, freeze INF/CAT/signed DLL/helper identities and verify signatures/membership. Update adapter expectations with mismatch/version/partial-init tests, retaining full hashes and backend-neutral bridge contracts.
3. Install only qualified exact runtime. Qualify isolated virtual creation, selected XInput slot/state/rumble callback and clean removal; no physical input/Chatpad connection. Stop on reboot requirement without reboot.
4. Capture physical/security invariants, run one final comprehensive regression, rerun read-only PreflightC3 and publish canonical evidence with independent readbacks/sidecar-last completion. C3_READY requires all original C2R2 acceptance criteria.

Restrictions: no physical Xbox/WinUSB rebinding, oem104/xusb22/Chatpad removal, physical restart/USB reads/writes, activation/keyboard output/physical rumble, security/BCD/trust changes, reboot, unrelated virtual software, stable/legacy edits, GPU or stress tests. C3 needs a later human request.

Inspect AGENTS.md, PROJECT-STATE.md, DECISIONS.md, latest WORKLOG, CHATPAD-HIDMAESTRO-QUALIFICATION.md, tools/ChatpadVirtualXbox/{upstream.json,HidMaestroBackend.cs,BackendAvailability.cs}, new qualification tools and canonical receipt. Inspect pinned upstream DriverBuilder.cs/HMContext.cs before lifecycle calls.

Read-only commands:

    pwsh -NoProfile -File tools/Get-ChatpadHidMaestroQualification.ps1 -ReferenceRepository artifacts/task-8lc1/hidmaestro-reference
    pwsh -NoProfile -File tools/Test-ChatpadHidMaestroQualification.ps1
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PreflightC3

Current expected audit exit 2/BLOCKED and preflight C3Ready=false. Never force PASS.
