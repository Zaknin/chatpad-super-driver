# Next Task

## Exact current state

- **Completed branch:** `analysis/windows11-transport-architecture`.
- **Completed task starting commit:**
  `6881fc492af50b7f28977d306fad369a2f6a309f`.
- **Architecture checkpoint:** commit named
  `docs: design windows 11 chatpad transport architecture`; verify its full
  hash against `origin/analysis/windows11-transport-architecture` before
  beginning.
- **Authoritative design:**
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`.
- The conditional design direction is a device-specific lower filter on the
  physical `USB\VID_045E&PID_028E`/`XnaComposite` node beneath `xusb22`.
- No attachment candidate is preferred yet because current default-control and
  Chatpad input-transfer access are unproven.
- No runtime, project, INF, installation, or hardware behavior was added.

## Next recommended objective

Define a kernel-safe transport-adapter interface and fully mocked,
WDF-independent implementation. Connect the existing portable activation
executor to the neutral contract, model cancellation/device-generation
outcomes, and test descriptor/result translation without creating a WDF
request or hardware behavior.

## Required branch and starting commit

- Create a new `feature/` branch from the exact pushed architecture checkpoint
  named above.
- Require `git rev-parse HEAD` to match
  `origin/analysis/windows11-transport-architecture` and a clean tree before
  editing.

## Preconditions

1. Read `AGENTS.md` and all continuity documents.
2. Read `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`, especially sections
   11, 13, 14, 18, 20, and 22.
3. Inspect the current executor contract and tests before designing the seam.
4. Verify repository safety, legacy immutability, and prohibited ancestry.

## Safety restrictions

- Portable contract, mocks, and offline tests only.
- No WDF/USB/HID/IOCTL/URB request representation or submission.
- No device/interface handle, live enumeration, capture, descriptor query,
  timing sleep, or hardware operation.
- No INF, CAT, certificate, packaging, signing, installation, deployment,
  loading, service, or Device Manager change.
- Do not encode endpoint addresses, interface/pipe ordinals, response bytes,
  retries, acknowledgements, readiness, or periodic-request semantics.
- Keep `legacy/` immutable and generated outputs beneath ignored `artifacts/`.

## Acceptance criteria

- The adapter contract uses only kernel-safe neutral value types and preserves
  existing portable descriptor ownership.
- The mocked implementation covers success, failure, cancellation, removal,
  stale generation, and no-next-step-after-cancel behavior.
- The executor remains independent of WDF and hardware.
- No default-control or input-path capability is claimed or implemented.
- All applicable user-mode tests and kernel compile checks pass, repository
  safety passes, and driver/project isolation is documented.

## Inspect first

1. `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`
2. `src/protocol/ChatpadProtocol/`
3. `tests/ChatpadProtocolTests/`
4. `tests/kernel/ChatpadProtocolKernelCompileCheck/`
5. `src/driver/ChatpadFilter/`
6. `docs/DECISIONS.md`
