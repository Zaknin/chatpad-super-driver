# Offline Request-Owner State Model

This checkpoint implements the first pure request-owner state model for future
Chatpad activation work. It is a portable C model and test harness only. It
does not create, format, submit, cancel, complete, install, load, sign, package,
or access any Windows driver object, USB target, device, registry key, service,
or Driver Store state.

## Scope

- Starting branch: `feature/offline-kmdf-request-owner-design`.
- Starting commit: `8444c0199144a6ccb24e8463a1778befe05736ec`.
- New branch: `feature/offline-request-owner-state-model`.
- Implementation source:
  `src/transport/ChatpadRequestOwnerModel/`.
- Offline tests:
  `tests/transport/ChatpadRequestOwnerModelTests/`.
- Wrapper:
  `tools/Test-ChatpadRequestOwnerModel.ps1`.

The model refines the design in
[Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md)
into a caller-owned, WDF-independent state machine that future KMDF code can
adapt behind explicit effects.

## Non-scope

This checkpoint deliberately has no:

- WDF, WDM, NTDDK, USB, HID, SetupAPI, Configuration Manager, WinUSB, IOCTL,
  URB, handle, thread, sleep, timer, allocation, endpoint, pipe, target, or
  hardware dependency;
- production driver callback integration;
- request object, transfer memory, target discovery, formatting, send,
  completion callback, cancel callback, or D0-exit implementation;
- INF, catalog, certificate, package, signing, staging, installation, service,
  registry, Driver Store, driver load, PnP query, device query, USB capture, or
  controller/Chatpad action.

## Model surface

`ChatpadRequestOwnerModel` exposes a single caller-owned
`ChatpadActivationRequestOwner` and dispatches value events into effects. The
model uses the existing neutral `ChatpadTransportOperationToken` identity shape
without calling the transport adapter or lifecycle core.

States:

```text
UNAVAILABLE
IDLE
PREPARING
READY
FORMATTED
SUBMITTING
IN_FLIGHT
CANCEL_CALLING
CANCEL_PENDING
COMPLETING
AWAITING_CALL_RETURN
RETIRING
DRAINING
FAULTED
```

Events:

```text
MAKE_AVAILABLE
MAKE_UNAVAILABLE
REQUEST_ADMISSION
BEGIN_OPERATION
PREPARATION_SUCCEEDED
PREPARATION_FAILED
FORMATTING_SUCCEEDED
FORMATTING_FAILED
SEND_CALL_BEGINS
SEND_RETURNED_ACCEPTED
SEND_RETURNED_FALSE
REQUEST_CANCELLATION
CANCEL_CALL_BEGINS
CANCEL_CALL_RETURNED
COMPLETION_BEGINS
COMPLETION_FINISHES
RETIREMENT_COMPLETES
BEGIN_DRAIN
FAULT
```

The dispatcher clears caller effects before validation. Rejected transitions
leave state unchanged and emit no effects. Faulting transitions enter
`FAULTED` and emit `RecordDiagnosticFault`.

## Effects contract

The model emits intent rather than performing framework work:

- acquire or release lifecycle admission;
- caller may prepare;
- caller may format;
- caller may begin the send call;
- caller may begin the cancel call;
- completion or initiator owns terminal retirement;
- sequence may advance or must abort;
- owner may be reused;
- caller must wait for send or cancel framework-call return;
- stale completion was consumed;
- diagnostic fault should be recorded.

One acquired lifecycle obligation can produce exactly one release effect for
the captured generation. Cancellation alone does not release the obligation.
A successful send gives terminal ownership to completion. A false send return
retires through the initiating path and aborts the sequence. Duplicate terminal
observations do not release twice.

## Race and accounting coverage

The test executable validates:

- all `14 x 19 = 266` state/event classifications;
- rejected-transition atomicity and cleared effects;
- faulting transition behavior;
- immediate completion before send-call return;
- send-return false after publication;
- completion while send and cancel call pins are outstanding;
- cancellation before and after send acceptance;
- cancel-return after completion;
- duplicate completion and duplicate cancellation;
- stale completion consumption;
- generation and operation mismatches;
- preparation and formatting failures;
- draining and unavailable ownership;
- invalid initialization, null arguments, snapshot, and invariant failures;
- bounded deterministic sequence exploration to depth 10.

The dual send/cancel-pin race is injected in tests by constructing an otherwise
valid awaiting-call-return snapshot with both call pins set. This tests the
state invariant and terminal accounting without creating WDF objects or calling
framework APIs.

## Semantic guard

`tools/Test-ChatpadRequestOwnerModel.ps1` performs a source/project guard
before building:

- model files contain no WDF/WDM/kernel/USB/HID/PnP/SetupAPI symbols or
  headers;
- model files contain no dynamic allocation, sleep, event, thread, handle, or
  device I/O surface;
- no file-scope mutable static state exists;
- the dispatcher clears effects before validation;
- tests contain rejected-transition atomicity and cleared-effects checks;
- the unconfirmed `90 00` payload text is absent;
- all 14 states and 19 events are declared and tested;
- the model project compiles exactly `ChatpadRequestOwnerModel.c`;
- the model project has no project references;
- `ChatpadFilter` source/project files contain no `ChatpadRequestOwner`
  reference.

The guard passes in both Debug and Release wrapper runs.

## Build and validation evidence

Fresh final validation evidence is recorded in `docs/WORKLOG.md` for this
checkpoint. The request-owner wrapper requires:

- semantic guard: PASS;
- transition states: 14;
- transition event classes: 19;
- transition combinations: 266;
- scenario count: 30;
- exploration depth: 10;
- failed assertions: 0;
- generated outputs contained beneath `artifacts/`.

Full solution Debug and Release builds use the WDK-capable Visual Studio
Community MSBuild path reported by `tools/Get-DriverBuildEnvironment.ps1`.
An earlier generic BuildTools MSBuild run failed with `MSB8020` because that
installation does not contain the Windows kernel-mode driver toolset; it is
recorded as a tool-selection failure, not as a source failure.

## Remaining boundary

This model is not production driver behavior. Future work must still adapt the
model into compile-only KMDF request-context definitions before any object
creation, target access, live formatting, submission, completion callback,
cancellation callback, executable delay, or D0-exit mechanism is authorized.
