# Next Task

Current state: TASK8L-C2R3 isolated HIDMaestro UMDF/XInput qualification PASS; C3Ready=true on this host. Packages oem106/oem107 retained, exact local cert trust unchanged, TESTSIGNING=false/HVCI=true. Physical xusb22/oem104 remains Code52 with unchanged binding/filters; C3 not started.

Next recommended objective: separately authorized TASK8L-C3 bounded physical WinUSB bridge acceptance. Do not create a task/chat or start C3 automatically.

Required branch: feature/chatpad-winusb-bridge-poc. Starting commit must be the exact C2R3 coherent commit recorded by Git and artifacts/task-8lc2r3/result-manifest.json (expected direct child of c989b04a5e0570726077ed188c4205201c8aef15, message "feat: qualify locally trusted HIDMaestro UMDF runtime"). Verify clean origin0/0 and canonical publication-receipt plus every sidecar/hash independently; publication is not proved merely by this pre-publication document.

Read AGENTS.md, PROJECT-STATE.md, DECISIONS.md, this file and latest WORKLOG first. Inspect tools/ChatpadVirtualXbox/RuntimePackageIdentity.cs, tools/ChatpadHidMaestroPackage.psm1, tools/ChatpadBinding/C3Planning.psm1, tools/Invoke-ChatpadC3.ps1 and docs/CHATPAD-HIDMAESTRO-LOCAL-PACKAGE.md. Re-read the actual C3 human instruction before any mutation.

Preconditions: exact intended physical container/instance and Microsoft restoration candidate freshly verified; exact signed WinUSB package and recovery files; six frozen HIDMaestro package hashes/current signer trust; hash-pinned real8-state/rumble/cleanup evidence; no present or phantom HIDMaestro devices; shared045E:028E GameInput/OEM metadata absent; no ROOT/SWD controller-index0 conflict; GameInputSvc already Running with unchanged start type; fresh component/readiness hashes/HEAD and effective CI state. Run tools/ChatpadBinding.ps1 -PreflightC3 and require PASS without forcing it. C2R1 proof is intentionally scoped to TASK8L-C2R1; keep C2R3 canonical evidence separately verified.

Safety: absent explicit new authorization, no physical bind/restart, extension removal, USB activation/reads/writes, SendInput or physical rumble. No TESTSIGNING/BCD/HVCI/SecureBoot/trust changes, stock HIDMaestro installer, new cert/private-key export, runtime DLL modification, USBIP/ViGEm/OpenVR installation, reboot, stable driver/protocol or legacy edits. Catalog regeneration changes identity and requires a new qualification; do not silently refresh its pin.

Future acceptance: bounded ordered C3 stages and exact physical-to-virtual routing, Chatpad input and virtual/physical rumble if explicitly authorized, verified cleanup and independent Microsoft rollback. Do not call the test-signed fallback healthy in normal Windows: optional extension load qualification remains blocked. Initial physical activation, real transport/key reports, SendInput, Guide/headset/lifecycle/latency and rollback are still UNTESTED.

HIDMaestro removal plan is independently prepared/identity-checked, not executed: companion oem107 first then main oem106 with /uninstall, never /force or /reboot; stop on reboot-required/error and verify physical/security/trust invariants. SDK disposal leaves an owned SWD phantom; C2R3 wrapper removes only exact recorded task-owned non-present ID. Future C3 must likewise prove no stale device rather than equating slot disappearance with full cleanup.
