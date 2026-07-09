# Next Task

## Objective

TASK 8C-0 — next-lane readiness preflight after accepted rollback/no-op package evidence audit

## Current State

- **Branch:** `feature/native-adapter-execution-envelope-verifier`
- **Required starting commit:** the TASK 8B-7 commit that records TASK 8B-6C audit acceptance
- **Accepted audit target:** `356f79963489fb999245df23e70f22740564789e`
- **Accepted audit parent:** `ffad232eea24fb2dcda0ce09aa6809180cad880c`
- **Accepted audit result:** TASK 8B-6C `PASS` / `ACCEPTED`
- **Audit upstream state:** `0/0`; working tree clean at audit
- **Evidence state:** rollback/no-op package evidence committed, pushed, and audited

## Evidence Reference

- **Evidence path:** `docs/evidence/exact-instance-binding-rollback-no-op-package.json`
- **Schema:** `chatpad-exact-instance-binding-rollback-no-op-package-v1`
- **Status:** `EXACT_INSTANCE_BINDING_ROLLBACK_NO_OP_PACKAGE_DEFINED_NO_ROLLBACK_IMPLEMENTED_NO_RESTORE_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
- **Readiness:** `READY_FOR_ROLLBACK_NO_OP_PACKAGE_EVIDENCE_AUDIT_ONLY`
- **Evidence hash (SHA-256):** `03AA4058D9CDB6DA00ED7EF4DC3FEFB01E314438CA07974E73659B8D8C4FDCD3`
- **Hash method:** `canonical_lf_text_sha256`
- **Source commit:** `ffad232eea24fb2dcda0ce09aa6809180cad880c`
- **Operator confirmation ID:** `operator-confirmation-c445630fbb303c7c`
- **Accepted target instance ID:** `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`

## Preconditions

1. Verify the live branch, HEAD, parent, upstream sync, and `git status` before any next-lane work.
2. Verify the rollback/no-op package evidence hash remains `03AA4058D9CDB6DA00ED7EF4DC3FEFB01E314438CA07974E73659B8D8C4FDCD3`.
3. Verify the manifest section `exact_instance_binding_rollback_no_op_package` records TASK 8B-6C `PASS` / `ACCEPTED` and remains flat with no nested `safety_state` or `readiness_decision`.

## Safety Restrictions

- binding implementation/execution remains unauthorized.
- rollback package implementation remains unauthorized.
- rollback implementation remains unauthorized.
- restore remains unauthorized.
- Native execution remains `NOT_IMPLEMENTED`.
- Live readiness remains `BLOCKED`.
- Blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Do not perform live/device queries, identity capture, new operator confirmation collection, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access, compile-output access, or metadata parsing unless a later task explicitly authorizes that exact action.

## Acceptance Criteria

- Next-lane preflight confirms the accepted rollback/no-op package evidence audit state.
- No unsupported claim is introduced about rollback package implementation, rollback implementation, restore, binding, native execution, SetupAPI/Newdev, Windows mutation, driver action, artifact access, compile-output access, metadata parsing, or blocker removal.
- Continuation docs remain consistent with the live repository state.
