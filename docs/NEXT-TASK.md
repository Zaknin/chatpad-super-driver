# Next Task

## Exact Current State

- Required branch: `feature/offline-kmdf-production-orchestration-provenance-final-remediation`.
- Required starting commit: the commit containing this file, with subject `test: finalize production orchestration provenance evidence` and parent `6a586bb2490e6a2611987a229c8c9d11d32fab01`.
- Frozen implementation: `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Manifest: schema `1.6.0`, 102 mandatory IDs and 102 entries.
- Contracts: 26-path production runtime/link boundary and 32-path A/B wrapper-build boundary.
- Retained evidence: four isolated sets, each with 22 raw TLOGs, 15 objects, 2 emitted libraries, one SYS, one PDB, strict parser output, source closure, library closure, complete input provenance, PDB inventory, negative extra-TLOG test, and same-set closure.

## Recommended Objective

Perform an independent read-only audit of the final provenance-remediation commit and ignored retained evidence.

## Preconditions and Acceptance

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0 ahead/behind, and clean worktree/index.
2. Rehash the producer, raw-TLOG validator, both contracts, freeze record, 102 manifest entries, four raw roots, retained intermediates, retained PDBs, and canonical binaries.
3. Independently add an extra copied TLOG under a temporary duplicate evidence root and confirm strict root enumeration rejects it; do not alter the accepted evidence root.
4. Confirm production source/project/solution/INF and `legacy/` identity against `6a586bb`, `499f6ea`, and `efb7295` as applicable.
5. Confirm every Full guard counter is zero and the documented self-reference limitation is accurate.

## Safety Restrictions

- Read-only audit only; do not regenerate accepted evidence.
- Do not sign, package, create certificates/keys, install, load, mutate Windows, query devices, access USB/HID/XUSB, access a controller or Chatpad, discover targets, or perform request actions.
- Do not modify `legacy/`.
