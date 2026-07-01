# Next Task

## Exact Current State

- Required branch: `feature/offline-kmdf-production-orchestration-provenance-closure-remediation`.
- Required starting commit: the commit containing this file, with subject `test: close production orchestration provenance gaps` and parent `499f6eae4b0e8a6fd4dbf3186c44906b5e6d4201`.
- Frozen implementation: `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Manifest: schema `1.5.0`, 99 mandatory IDs.
- Contracts: 26-path production runtime/link boundary and 32-path A/B wrapper-build boundary.
- Retained evidence: four isolated sets, each with 22 raw TLOGs, 15 objects, 2 emitted libraries, strict parser output, source closure, library closure, and same-set closure.

## Recommended Objective

Perform an independent read-only audit of the final provenance-closure commit and ignored retained evidence.

## Preconditions and Acceptance

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0 ahead/behind, and clean worktree/index.
2. Rehash the producer, both contracts, freeze record, 99 manifest entries, four raw roots, retained intermediates, and canonical binaries.
3. Independently add an extra copied TLOG under a temporary duplicate evidence root and confirm strict root enumeration rejects it; do not alter the accepted evidence root.
4. Confirm production source/project/solution/INF and `legacy/` identity against `499f6ea` and `efb7295`.
5. Confirm every Full guard counter is zero and the documented self-reference limitation is accurate.

## Safety Restrictions

- Read-only audit only; do not regenerate accepted evidence.
- Do not sign, package, create certificates/keys, install, load, mutate Windows, query devices, or access USB, HID, XUSB, a controller, or a Chatpad.
- Do not modify `legacy/`.
