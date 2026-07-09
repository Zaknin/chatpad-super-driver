# TASK 8C-4 — validate manifest/docs update for next non-mutating implementation contract scope evidence

## Current State

- **Branch:** `feature/native-adapter-execution-envelope-verifier`.
- **Starting commit:** `0ab8c6df594f278602212fadfef1d3675bee54ef`.
- **Expected status before validation:** modified docs/manifest files from TASK 8C-3 plus untracked `docs/evidence/exact-instance-binding-next-non-mutating-implementation-contract-scope.json`.
- **Evidence path:** `docs/evidence/exact-instance-binding-next-non-mutating-implementation-contract-scope.json`.
- **Evidence hash:** `A105F637D349E8CE324E57DB35D5F79D4614EBD2E511381D1480F20F52499666`.
- **Schema:** `chatpad-exact-instance-binding-next-non-mutating-implementation-contract-scope-v1`.
- **Status:** `EXACT_INSTANCE_BINDING_NEXT_NON_MUTATING_IMPLEMENTATION_CONTRACT_SCOPE_DEFINED_NO_IMPLEMENTATION_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`.
- **Readiness:** `READY_TO_DEFINE_NON_MUTATING_IMPLEMENTATION_CONTRACT_ONLY`.
- **Manifest section:** `exact_instance_binding_next_non_mutating_implementation_contract_scope`.
- **Recorded manifest source hash in evidence:** `9E81DB3EF9DA0CEA4BC03C6BA83FA77E72B6B99E6B399F9E6BA99480699EBB18`. Do not update this evidence-file hash; current manifest hash drift after TASK 8C-3 is expected.

## Safety Restrictions

This is validation-only unless a later task explicitly authorizes a narrow repair. Do not perform live/device query, identity capture, operator confirmation collection, rollback package implementation, rollback implementation, restore, binding implementation, binding execution, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access, compile-output access, metadata parsing, build, sign, package, install, load, bind, restart, or source/tool/native/driver code changes.

## Acceptance Criteria

- Verify the evidence file hash remains `A105F637D349E8CE324E57DB35D5F79D4614EBD2E511381D1480F20F52499666`.
- Verify manifest schema remains `chatpad-runtime-bringup-readiness-manifest-v4`.
- Verify manifest section `exact_instance_binding_next_non_mutating_implementation_contract_scope` exists and is flat.
- Verify manifest section records evidence path/hash/schema/status/readiness/source commit and TASK 8C-1/TASK 8C-2 provenance.
- Verify source evidence chain contains the eight expected roles and hashes.
- Verify safety/readiness fields preserve blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, live readiness `BLOCKED`, native execution `NOT_IMPLEMENTED`, and all implementation/mutation/action readiness flags false.
- Verify docs record TASK 8C-1 creation, TASK 8C-2 validation, evidence identity, branch, accepted rollback/no-op package evidence, unauthorized implementation/execution/restore state, and next lane remains non-mutating implementation contract only.
- Verify forbidden positive-claim scan is clean.

## Recommended First Checks

1. `git status --short`
2. Validate `docs/evidence/exact-instance-binding-next-non-mutating-implementation-contract-scope.json` with canonical LF hash.
3. Validate `docs/evidence/runtime-bringup-readiness-manifest.json` section `exact_instance_binding_next_non_mutating_implementation_contract_scope`.
4. Inspect docs tokens in `docs/PROJECT-STATE.md`, `docs/RUNTIME-BRINGUP-READINESS.md`, `docs/NEXT-TASK.md`, and `docs/WORKLOG.md`.
