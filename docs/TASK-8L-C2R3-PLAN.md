# TASK 8L-C2R3 — catalog-only qualification plan

Execute the supplied task inline on feature/chatpad-winusb-bridge-poc at c989b04a5e0570726077ed188c4205201c8aef15. Existing trusted certificate only; no new trust/key, BCD/security change, physical Xbox mutation or C3.

- [x] Reconcile clean branch/source/canonical C2R2 archive; capture certificate, physical and effective CI baselines.
- [x] Verify exact payload and certificate/EKU/chain; stage deterministic INF/DLL content; run installed WDK InfVerif/Inf2Cat, sign only CATs and verify every member. Freeze actual generated CAT hashes; never edit generated catalogs or claim fresh Inf2Cat byte determinism.
- [x] With all offline gates passing, stage only these two root-only UMDF packages using elevated PnPUtil; capture exact output/INF/SetupAPI errors. Stop on security rejection/reboot requirement.
- [x] If installation succeeds, qualify one virtual controller with existing real adapter, exact XInput slot/state/virtual output and cleanup. Inspect upstream lifecycle side effects before invocation; no stock installer calls. GameInputSvc already running prevents its prewarm config/start path.
- [x] If runtime succeeds, add exact CAT/signer/version/hash contract to the existing read-only runtime guard; focused tests then one final comprehensive Release regression.
- [x] Verify physical/security/trust invariants, read-only readiness and independent package removal plan. Local source review complete; independent reviewer unavailable due usage limit.
- [ ] Commit/push only requested branch and publish canonical evidence with native readbacks/sidecars last; completion comes from Git and receipts.

New task authorization supersedes C2R2's catalog-generation/signing/installation restriction for these exact UMDF packages. It does not authorize embed-signing runtime binaries, trust-store changes, stock deployment, physical Xbox operations or C3. A missing expected certificate, Windows rejection or reboot requirement stops dependent live work; publish BLOCKED evidence.
