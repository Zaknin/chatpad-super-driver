# Project State

*Last updated: 2026-06-30T00:30+04:00*

## Current state

- **Branch:** `feature/control-setup-translation`.
- **Starting checkpoint:** `55e84722a73ce1d65fde2af829986e9ee5d66995`.
- **Expected task commit:** `feat: add pure control setup translation`.
- **Pure translator:** `src/transport/ChatpadControlSetup/` converts one
  caller-provided `ChatpadActivationRequest` into explicit eight-byte setup
  data, data-stage direction, copied outbound payload/length, and expected
  inbound length.
- **Validation behavior:** invalid direction, direction-bit mismatch,
  inconsistent payload/inbound lengths, and capacity overflow reject
  deterministically; every failure with a non-null output clears the complete
  caller-owned output.
- **Confirmed data:** all six exact setup arrays pass; request 4 preserves
  outbound `09 00`; requests 3 and 5 expect two inbound bytes without response
  storage; confirmed fixtures contain no outbound `90 00`.
- **Native tests:** Debug and Release pass `141/141`; source/project guard and
  artifact containment pass.
- **Regressions:** protocol Debug/Release `610/610`; transport Debug/Release
  `186/186`; lifecycle Debug/Release `109/109`.
- **Kernel compatibility:** Debug and Release WDK compile checks pass and emit
  only `ChatpadProtocolKernelCompileCheck.lib` beneath `artifacts/`.
- **Driver:** Debug and Release compile-only builds pass, remain
  `Authenticode.NotSigned`, and contain no control-setup source or linker input.
- **Isolation:** `ChatpadFilter.vcxproj` has no project reference and compiles
  only lifecycle, driver, and device sources. The solution has no driver
  project dependency on the translator.
- **Safety:** translation performs no formatting, allocation, submission,
  completion, I/O, hardware access, device enumeration, installation, signing,
  packaging, deployment, loading, capture, elevation, or external-skill
  modification. `legacy/` remains unchanged.

## Unresolved blockers

- No Windows 11 default-control-pipe access is proven.
- Control-IN response bytes, acknowledgement, readiness, retry, timeout, and
  activation success remain unresolved.
- No WDF setup formatting, target, request, memory object, queue, endpoint,
  pipe, transfer, or continuous input behavior exists.
- No INF, device-specific installation/recovery path, signing, package,
  deployment, load, or hardware authorization exists.
