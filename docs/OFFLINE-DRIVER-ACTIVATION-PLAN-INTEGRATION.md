# Offline Driver Activation-Plan Integration

## Purpose and scope

This milestone proves that `ChatpadFilter` can compile and retain a dormant,
side-effect-free activation-step preparation API using the repository's
authoritative activation model, pure control-setup translation, and WDF setup
formatter. It does not make the driver operational.

- Starting branch:
  `feature/offline-inf2cat-package-validation`.
- Starting commit:
  `fad671d5d1ede2eda6f0a5defb0b0495c80cc39e`.
- Implementation branch:
  `feature/offline-driver-activation-plan-integration`.

## Architecture before and after

Before this milestone, activation requests and sequence metadata were compiled
only by portable projects, pure setup translation was separate, the WDF
formatter was isolated in a compile-only static library, and `ChatpadFilter`
compiled only lifecycle and callback scaffolding.

The production-driver compile graph is now:

```text
ChatpadActivationSequence
  -> ChatpadActivationRequests
  -> ChatpadControlSetup
  -> ChatpadWdfControlSetupFormatter
  -> ChatpadActivationPreparation
  -> dormant ChatpadFilter linker input
```

`ChatpadFilter.vcxproj` compiles those existing authoritative `.c` files
directly under the WDK toolchain. It does not copy their constants, link the
user-mode libraries, add a project reference, or link `ChatpadTransport`.
`/INCLUDE:ChatpadPrepareActivationStep` retains the dormant API without calling
it.

## Production module and API

The internal module is:

- `src/driver/ChatpadFilter/ChatpadActivationPreparation.h`;
- `src/driver/ChatpadFilter/ChatpadActivationPreparation.c`.

Its single entry point is:

```c
ChatpadActivationPreparationResult ChatpadPrepareActivationStep(
    size_t stepIndex,
    ChatpadActivationPreparation *output);
```

The result value distinguishes success, null output, invalid step, activation
model failure, pure translation failure, WDF formatting failure, payload
capacity overflow, and metadata inconsistency. Every non-null output is cleared
before validation and remains fully cleared on failure.

Successful output contains only a caller-owned
`WDF_USB_CONTROL_SETUP_PACKET`, direction, transfer length, fixed-capacity
outbound payload, expected inbound length, sequence/request indexes, and
before/after delay metadata. It contains no WDF handle, device or target
pointer, request, memory object, callback, lock, timer, event, allocation, or
mutable global state.

## Exact six-step verification

Portable tests continue to validate these authoritative setup bytes:

```text
40 a9 0c a3 23 44 00 00
40 a9 44 23 03 7f 00 00
40 a9 39 58 32 68 00 00
c0 a1 00 00 16 e4 02 00
40 a1 00 00 16 e4 02 00
c0 a1 00 00 16 e4 02 00
```

The WDK compile check consumes each step through the production API and
compares its setup bytes, direction, transfer length, outbound bytes, expected
inbound length, indexes, and delay metadata with fresh authoritative
sequence/translation output. It also compiles deterministic repeated calls,
null output, step-count boundary, large-index, and success-then-failure clearing
paths. The only confirmed outbound payload remains model-supplied `09 00` at
step 4; unconfirmed `90 00` is absent.

The formatter cannot safely be executed as a user-mode host test without
inventing a WDF runtime. Therefore the integrated WDF path uses the existing
WDK compile/link pattern, while exact portable behavior remains covered by the
native protocol and control-setup assertions.

Every authoritative step is valid, so none can naturally induce a translator
or formatter failure. The production enum retains explicit fail-closed mapping
for those results, but no production constant was altered and no invalid
parallel activation model was created merely to fabricate those failures.

## Build and test results

All commands used installed local toolchains and generated only ignored
outputs beneath `artifacts/`.

| Validation | Result |
| --- | --- |
| Full solution x64 Debug | PASS, exit 0 |
| Full solution x64 Release | PASS, exit 0 |
| ChatpadFilter x64 Debug | PASS, exit 0 |
| ChatpadFilter x64 Release | PASS, exit 0 |
| Protocol Debug / Release | 610/610 each |
| Transport Debug / Release | 186/186 each |
| Lifecycle Debug / Release | 109/109 each |
| Pure control setup Debug / Release | 141/141 each |
| Direct protocol regression | 610/610 |
| Kernel compatibility Debug / Release | PASS |
| WDF formatter and activation preparation Debug / Release | PASS |
| Repository safety before and after | PASS |

The first two solution-build attempts exposed output containment problems:
driver output and then stale intermediate files appeared in ignored `x64`
directories outside `artifacts/`. The project properties were moved to the
correct post-import evaluation point, the verified generated directories were
removed, and both solution configurations and affected containment checks then
passed.

## Driver artifacts

| Configuration | Path | Size | SHA-256 | Authenticode |
| --- | --- | ---: | --- | --- |
| Debug | `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys` | 15,872 bytes | `83C7D82BD77FA6F05690F0F4F610CF246042160D9E4A10D9032C44221B0A4AD6` | `NotSigned` |
| Release | `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys` | 12,288 bytes | `22D7A1DF6F051DBFB1AB835A08354391CDEDA7BC88F27BC6EB7CAACBD4A90139` | `NotSigned` |

Diagnostic logs show the preparation, request-model, sequence, translation,
and formatter objects as driver compile and linker inputs. Inf2Cat and DrvCat
were skipped; no INF, CAT, certificate, package, or signing output entered the
driver directories.

## Dormancy and safety proof

Semantic guards reject WDF device, target, request, memory, queue, timer, work
item, completion, cancellation, submission, IOCTL, URB, wait, and delay
execution surfaces in the integration slice. They also require the exact three
authoritative calls and reject `90 00`.

`driver.c`, `device.c`, and `driver.h` are unchanged and contain no reference
to `ChatpadPrepareActivationStep`. No existing runtime callback invokes it.

## Remaining boundary

This milestone proves only production-driver compilation of the dormant
preparation layer, reuse of the portable activation model, reuse of pure setup
translation, reuse of WDF setup formatting, and deterministic preparation of
all six steps.

It does not prove or authorize WDF request creation; USB target discovery;
control-pipe visibility; formatting against a live target; request submission;
completion or cancellation; actual timing or delays; activation effectiveness;
controller preservation; Chatpad input; keyboard output; driver loading;
signing; staging; installation; effective lower-filter placement; or a usable
driver.
