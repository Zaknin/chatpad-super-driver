# Next Task

## Exact current state

- Required branch:
  `feature/offline-runtime-instrumentation-implementation-remediation`.
- Required starting commit: the final commit containing this file, with subject
  `driver: remediate offline runtime instrumentation`.
- Required parent: `3546ace3892914935276ed74f39d2cd71a53858e`.
- Accepted design: `526f6bb055b485fdb459a9d303fc3f814da15e48`.
- Provider GUID: `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Trace schema / catalogue: schema `1`; 73 IDs and names.
- Manifest: `docs/evidence/runtime-instrumentation-implementation-manifest.json`,
  schema `1.1.0`.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.

## Next recommended objective

Perform an independent read-only audit of the offline runtime instrumentation
remediation.

## Preconditions

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read the required continuity files, the accepted design, this remediation
   document, the event-site inventory, equality and trace-volume reports, and
   the complete manifest.
3. Rehash all tracked manifest entries and retained ignored evidence without
   generating or modifying evidence.
4. Inspect the complete `3546ace..HEAD` diff and confirm authorized scope.

## Safety restrictions

- Audit only. Do not modify files or regenerate builds, guards, matrices,
  evidence, or logs.
- Do not sign, package, create certificates/keys, stage, install, load, start a
  trace session, mutate Windows, query devices, access USB/HID/XUSB/controller/
  Chatpad state, discover/open targets, or perform request operations.
- Do not modify `legacy/`.

## Acceptance criteria

- All 73 catalogue events have real source sites; phantom and side-effectful
  trace-argument counts are zero.
- Counter, overflow, pre-context terminal, cleanup, sequence-invariant, and
  event-1308 fields match the accepted design and remediation contract.
- Production behavior and target/request absence are preserved.
- Production guards remain Full and binary/contract checks are not weakened.
- The 19-scenario/228-assertion model and both 13-entry/301-assertion matrices
  are genuine independently configured PASS evidence.
- Debug/Release WPP equality, trace-volume bounds, binary identities,
  Authenticode state, and all manifest hashes verify.
- Continuation documents make no runtime or independent-acceptance claim.

## Inspect first

- `src/driver/ChatpadFilter/ChatpadRuntimeDiagnostics.h`
- `src/driver/ChatpadFilter/device.c`
- `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
- `tools/Test-ChatpadRuntimeInstrumentation.ps1`
- `tools/Test-ChatpadProductionOrchestrationInvocation.ps1`
- `tools/Test-ChatpadProductionOwnerInitialization.ps1`
- `tests/offline/RuntimeInstrumentationModel/`
- `docs/OFFLINE-RUNTIME-INSTRUMENTATION-IMPLEMENTATION.md`
- `docs/evidence/runtime-instrumentation-implementation-manifest.json`
