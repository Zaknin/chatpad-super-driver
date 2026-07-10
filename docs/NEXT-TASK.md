# TASK 8E-2 — Independent read-only audit of the non-executing native adapter implementation

## Current State

- **Required branch:** `feature/native-adapter-nonexecuting-implementation`.
- **Starting commit:** the TASK 8E-1 atomic implementation commit, subject `feat: implement non-executing native adapter surface`.
- **Evidence path:** `docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json`.
- **Contract evidence hash:** `1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080`.
- **Manifest section:** `nonexecuting_native_adapter_implementation`.
- **Implementation files:** `tools/ExactInstance/ChatpadNonExecutingNativeAdapter.psm1` and `tools/Test-ChatpadNonExecutingNativeAdapter.ps1`.
- **Blocker:** `BLOCKED_NATIVE_ADAPTER_IMPLEMENTATION_NOT_INDEPENDENTLY_AUDITED`.
- **Live readiness:** `BLOCKED`.
- **Native execution:** `NOT_IMPLEMENTED`.

## Safety Restrictions

This is independent read-only audit scope. Do not modify the repository. Do not perform live/device query, identity capture, operator confirmation collection, rollback package implementation, rollback implementation, restore, binding execution, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access, compile-output access, metadata parsing, build, sign, package, install, load, bind, or restart.

## Acceptance Criteria

- Verify the TASK 8E-1 commit identity, parent `79955ef434ed4424a72b6dea8ec870a66ad5d8ef`, subject, complete changed-file list, clean tree, upstream `0/0`, and matching remote branch.
- Verify the contract evidence hash and the two implementation-file hashes recorded by TASK 8E-1.
- Review the public exports, private fake seam, exact ordered target validator, and fail-closed results; confirm no production backend is selected or loaded.
- Re-run the focused test in Windows PowerShell 5.1 and PowerShell 7 only, confirming 12 tests / 81 assertions each, adversarial-capability rejection, SessionState non-extraction, zero failed-validation fake calls, and one fake non-native seam call.
- Verify the evidence and manifest parse, maintain flat structure, preserve TASK 8D history, record all zero prohibited-operation counters, and use the narrowed audit blocker without claiming live, native, binding, or runtime success.
- Verify no live query, native invocation, SetupAPI/Newdev call, binding, mutation, driver action, rollback, restore, artifact access, compile-output access, build, or helper/temp-file creation occurred.
