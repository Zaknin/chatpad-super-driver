# TASK 8L-C2R2 qualification plan

Goal: qualify revision `1c126ed4780322454391b7be782230b35b0810f6` without physical Xbox or security mutations; publish evidence even when installation is blocked.

The user task is the execution specification. Continue inline on the requested existing feature branch. One coherent qualification/tooling/continuity commit, then push only that branch. No additional task is created.

- [x] Reconcile branch/HEAD, license/notices, live physical state and read-only preflight.
- [x] Inspect release members, embedded x64 package bytes and installer side effects.
- [x] Add a read-only payload qualification tool and focused missing/mismatched-file tests; preserve red/green evidence under ignored artifacts.
- [x] Verify signatures, version/architecture and exact source identity. If catalogs/trust prerequisites fail, stop before signing, installation or context construction.
- [x] Build the existing real adapter Release with two workers; run one comprehensive regression and focused qualification tests.
- [x] Capture final preflight and physical/security invariants; review diff and update continuity with exact limitations.
- [ ] Commit/push, publish deterministic evidence with native sidecar-last/readback publisher, verify clean status and remote 0/0.

Ruling: upstream's missing catalogs and locally generated trust are a Workstream C failure. No installation, live adapter/XInput/rumble tests or alternate backend is attempted. Offline mocks cannot satisfy those acceptance criteria. Audit tooling is the only implementation change; existing adapter guards and stable/legacy sources stay intact.
