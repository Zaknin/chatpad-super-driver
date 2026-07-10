# TASK 8H-2 — Repeated independent read-only audit of the remediated explicit one-shot live-execution authorization gate

## Current state

- **Required branch:** `feature/native-adapter-live-execution-authorization-gate`.
- **Required starting commit:** the documentation-consistency commit with subject
  `docs: record task 8g audit closure`; derive its exact hash from Git after
  commit creation.
- **Required parent:** `badb3fc3c29e6e7bc3ae3bb6a4ae86af49027865`.
- **TASK 8H-1R1 remediation commit:** `badb3fc3c29e6e7bc3ae3bb6a4ae86af49027865`
  (`fix: harden live authorization gate preconditions`), parent
  `09711c59f272dfaf275b7f7442c607c9c148d34a`.
- **TASK 8G closure basis:** TASK 8G-2 passed and directly closed the
  execution-coordinator source lane for audited commit
  `79ec174dabd7e73f2d01021168921021bc118702`; no separate TASK 8G acceptance
  or lane-close commit is required.
- **First TASK 8H-2 audit result:** failed because of acknowledgement coercion,
  incomplete runtime source hashing, and stale TASK 8G continuity documentation.
- **Evidence:** `docs/evidence/live-execution-authorization-gate-task-8h-1.json`.
- **Evidence SHA-256:** `2EAC8D3C707C53F77859620DC9D7D43903DC61F334774898BBFD56944977DBF2`.
- **Manifest section:** `live_execution_authorization_gate`.
- **Current blocker:**
  `BLOCKED_NATIVE_ADAPTER_LIVE_EXECUTION_AUTHORIZATION_GATE_NOT_INDEPENDENTLY_AUDITED`.
- **Live readiness:** `BLOCKED`.

## Preconditions

- Verify branch, HEAD, parent, clean worktree/index, upstream sync, and matching remote branch.
- Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest `docs/WORKLOG.md` entries.
- Confirm TASK 8E, TASK 8F, and TASK 8G source/evidence identities remain unchanged and the TASK 8G evidence identity is
  `BB2016A9CFD85BFCA06862E7B3D386EE611355AA2416778BFDCB49C7A6C0BD12`.
- Confirm TASK 8G closure grants no live execution authority and production-provider
  execution remains unavailable.

## Audit scope

- Strict read-only inspection only: do not edit, stage, commit, push, execute native APIs,
  query devices, bind, mutate Windows, install, load, restart, rollback, restore, package,
  sign, build, or open compile outputs.
- Verify the live gate requires every explicit input, including the exact phrase
  `AUTHORIZE_ONE_LIVE_NATIVE_APPLY_ATTEMPT`, exact ordered target chain, accepted evidence
  identities, caller-supplied critical source hashes matching the fixed accepted inventory,
  runtime current-file hashing of the fixed source inventory, and literal Boolean `true`
  for both acknowledgements.
- Verify single-item arrays, string booleans, stale current files, missing current files,
  directory substitutions, and path traversal are rejected fail-closed.
- Verify recording authorization and live authorization are separate types and cannot be
  converted, wrapped, copied, serialized, or transferred into each other.
- Verify the one-shot live authorization is process/reference/fingerprint bound and consumed
  once before any fake consumer path.
- Verify production provider registration, selection, construction, loading, and invocation
  remain unavailable and all prohibited counters remain zero.
- Run TASK 8E, TASK 8F, TASK 8G, and TASK 8H focused tests under both runtimes, the canonical
  validator, `-RunTask8GRegression`, and `-RunTask8HRegression`.

## Acceptance criteria

- Report `PASS` only if evidence/source/test hashes, exact public/private/managed surfaces,
  manifest/evidence equality, source-integrity rejection, literal-acknowledgement rejection,
  concurrency, replay, type-confusion rejection, validator, and both-runtime results match
  exactly with zero defects.
- Confirm no live authority was exercised and no production/native/device/Windows mutation
  path was invoked.
- A passing audit closes this authorization-gate source lane only. It must not authorize or
  perform live execution; a later live execution task requires a separate explicit operator
  instruction.
