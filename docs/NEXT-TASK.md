# Next Task

## Objective

Perform an independent strict read-only audit of the remediated
prior-driver/provider identity capture result commit.

This next task is not operator confirmation collection, rollback
implementation, restore execution, binding implementation, binding execution,
dry-run execution, native execution, SetupAPI/Newdev invocation, Windows
mutation, driver action, live observation, hardware access, or artifact/
compile-output access.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required parent commit before this remediation transition:
  `e7a385826f9d2c22c2e70f86d7588409cd3ff2dc`.
- Required commit subject:
  `docs: remediate prior identity evidence shape`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Remediated result evidence path:
  `docs/evidence/exact-instance-binding-prior-driver-provider-identity-capture-result.json`.
- Result evidence schema:
  `chatpad-exact-instance-binding-prior-driver-provider-identity-capture-result-v1`.
- Result status:
  `PRIOR_DRIVER_PROVIDER_IDENTITY_CAPTURED_NO_MUTATION_NO_NATIVE_IO`.
- Manifest path:
  `docs/evidence/runtime-bringup-readiness-manifest.json`.
- Manifest schema:
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entries: `49`.
- Blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Binding implementation status: `NOT_IMPLEMENTED`.
- Binding implementation authorized: `false`.
- Binding implementation performed: `false`.
- Binding execution performed: `false`.
- Prior-driver/provider identity captured: `true`.
- Original capture result live query performed: `true`.
- Read-only current-state identity query performed: `true`.
- Read-only current-state identity query count: `4`.
- New live observation performed by remediation: `false`.
- Hardware access performed by remediation: `false`.
- Artifact opening/access by remediation: `false`.
- Artifact/compile-output I/O by remediation: `false`.
- Compile-output hash verification by remediation: `false`.
- Metadata parsing by remediation: `false`.
- Native library load count: `0`.
- Entry-point resolution count: `0`.
- SetupAPI/Newdev invocation count: `0`.
- Windows mutation count: `0`.
- Driver action count: `0`.

## Required Audit Points

Verify the remediation points explicitly:

1. `accepted_dry_run_summary` includes:
   - `partial_vid_pid_candidate_count = 3`
   - `usb_interface_partial_candidate_count = 1`
   - `read_only_current_state_device_query_count = 4`
2. `exact_commands_run` contains only:
   - `Get-Date`
   - `Get-PnpDevice -PresentOnly`
   - `Get-PnpDeviceProperty -InstanceId 'USB\VID_045E&PID_028E\1C21F10'`
   - `Get-PnpDeviceProperty -InstanceId 'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00'`
   - `Get-PnpDeviceProperty -InstanceId 'HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000'`
3. Repository/source-evidence read commands, if retained, are recorded only in
   separate supporting fields and are not mixed into `exact_commands_run`.

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, audit target commit identity,
   subject, parent, upstream, remote equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/exact-instance-binding-prior-driver-provider-identity-capture-result.json`
3. Confirm no tool, source, INF, project, solution, parser, verifier,
   offline-suite, packaging, signing, staging, deployment, binary, artifact,
   frozen-output, generated-output, or `legacy/` path changed.

## Audit Scope

- Verify target commit Git identity, subject, parent, changed paths, and push
  state.
- Verify result evidence JSON and manifest JSON parse successfully.
- Verify manifest evidence hash for the remediated capture result matches the
  canonical LF text hash of the result evidence file.
- Verify result evidence schema/status.
- Verify accepted dry-run summary fields listed above.
- Verify final `exact_commands_run` command list listed above.
- Verify supporting repository/source-evidence read command fields do not imply
  new execution, new live query, new identity capture, mutation, binding,
  native execution, SetupAPI/Newdev invocation, driver action, or artifact/
  compile-output access.
- Verify accepted three-node target chain and shared ContainerId.
- Verify target InstanceId and captured target identity fields.
- Verify captured parent and child identity fields.
- Verify unavailable/skipped property reasons.
- Verify failed commands remain empty.
- Verify capture preconditions and rejection/no-op result.
- Verify final capture decision remains `CAPTURE_ACCEPTED`.
- Verify prior-driver/provider identity captured remains true.
- Verify the original capture result still records live query and read-only
  identity query count, while the remediation performed no new live query,
  device query, hardware access, native execution, Windows mutation, driver
  action, or artifact/compile-output access.
- Verify live readiness remains `BLOCKED`.
- Verify native execution remains `NOT_IMPLEMENTED`.
- Verify execution authorized remains `false`.

## Safety Restrictions

This audit is strict read-only. Do not collect operator confirmation. Do not
implement rollback. Do not perform restore. Do not implement or execute
binding. Do not perform new live observation. Do not run device query commands,
hardware access commands, binding execution, dry-run execution, native adapter
execution, SetupAPI/Newdev, verifier behavior tests, offline-suite behavior
tests, the static parser, the full compile-output validator, generator, full
exact/readiness suites, build, package, sign, install, load, bind, restore,
restart, `pnputil`, `devcon`, driver/service mutation, or artifact/
compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  documentation/manifest-only remediation transition without self-reference.
- Result evidence JSON and manifest JSON parse successfully.
- Remediation point 1 and remediation point 2 above pass exactly.
- Manifest schema remains `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entry count remains `49`.
- Manifest hash for
  `docs/evidence/exact-instance-binding-prior-driver-provider-identity-capture-result.json`
  matches the remediated evidence file.
- Documentation consistency, changed-path safety, forbidden vocabulary scan,
  added-line prohibited-action review, no-tool-file-change review, and
  `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/RUNTIME-BRINGUP-READINESS.md`
7. `docs/evidence/exact-instance-binding-prior-driver-provider-identity-capture-result.json`
8. `docs/evidence/exact-instance-binding-dry-run-result.json`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
