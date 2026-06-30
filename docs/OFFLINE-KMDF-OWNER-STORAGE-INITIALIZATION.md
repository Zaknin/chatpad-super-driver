# Offline KMDF Owner Storage Initialization Checkpoint

This checkpoint implements the first source slice after the dormant object
lifecycle design: ordinary C storage initialization and pre-object validation
for the future activation request owner. It creates no framework object and
does not connect the helper to `ChatpadFilter`.

## Scope

The implementation adds two APIs to the isolated
`ChatpadKmdfRequestOwnerContext` module:

- `ChatpadKmdfRequestOwnerInitializeStorage`;
- `ChatpadKmdfRequestOwnerValidatePreObjectState`.

The helper initializes only ordinary owner storage:

- owner signature and version;
- initialization mask;
- embedded pure `ChatpadActivationRequestOwner` model;
- null future WDF handle fields;
- zeroed outbound and inbound fixed transfer arrays;
- zeroed completion snapshot.

Successful initialization sets only
`CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`. It does not set
`CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY`, because no spinlock, request,
or memory object exists in this checkpoint.

## Validation contract

`ChatpadKmdfRequestOwnerValidatePreObjectState` clears the caller-provided
validation output before returning any non-null-output result. It distinguishes:

- null owner;
- null validation output;
- invalid signature;
- unsupported version;
- invalid initialization mask;
- pure-model initialization failure;
- invalid pure-model state;
- pre-existing framework handle;
- premature owner-ready publication;
- active operation or lifecycle obligation;
- nonzero completion snapshot;
- nonzero transfer storage;
- invariant failure;
- repeated initialization.

The validation output records the typed result, an invariant mask, the pure
model invariant result, and the pure model snapshot.

## Pre-object success invariants

A successful pre-object owner has:

- `Signature == CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE`;
- `Version == CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION`;
- `InitializationMask == CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`;
- `Request == NULL`;
- `OutboundMemory == NULL`;
- `InboundMemory == NULL`;
- `BookkeepingLock == NULL`;
- zeroed `TransferStorage.OutboundBytes[2]`;
- zeroed `TransferStorage.InboundBytes[2]`;
- zeroed completion snapshot with `CompletionClass ==
  CHATPAD_REQUEST_OWNER_COMPLETION_NONE`;
- pure model invariant result `CHATPAD_REQUEST_OWNER_INVARIANT_OK`;
- pure model snapshot in `CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE`;
- invalid generation, operation sequence, and activation step constants from
  the authoritative pure model;
- no active operation, lifecycle obligation, send pin, cancel pin, terminal
  marker, sequence advance, release effect, or stale completion marker.

The exact two-byte capacities remain compile-time invariants through `C_ASSERT`
in the context source and compile-check target.

## Explicit non-scope

This checkpoint does not:

- create `WDFDEVICE`, `WDFREQUEST`, `WDFMEMORY`, `WDFSPINLOCK`, USB targets,
  I/O targets, queues, timers, work items, or callbacks;
- allocate WDF context storage or attach context to a real framework object;
- call request reuse, formatting, completion-registration, send, cancellation,
  target start/stop, or `IoCallDriver`;
- modify `DriverEntry`, `EvtDeviceAdd`, PnP/power callbacks, or the live
  `ChatpadFilter` device context;
- add the context module to the production driver;
- modify INF, catalog, signing, packaging, staging, installation, service,
  registry, Driver Store, or device state;
- run InfVerif or Inf2Cat;
- access hardware.

## Host-execution limitation

The implemented helper is the exact production helper and includes WDK/KMDF
handle types. This checkpoint intentionally does not create a fake WDF runtime
or duplicate WDF handle typedefs/layout for host execution. Validation is
therefore compile-only under the installed WDK toolchain, plus semantic guards
that inspect the production source for prohibited runtime surfaces and required
pre-object invariants.

## Semantic guard

`tools/Test-ChatpadKmdfRequestOwnerContext.ps1` now verifies:

- storage initializer and pre-object validator are present;
- the pure request-owner model initializes, validates invariants, and provides
  the authoritative snapshot;
- typed null-owner, null-validation, handle-present, active-operation, and
  repeated-initialization results exist;
- validation mask bits include pre-object ready, no framework handles, and
  model baseline;
- every future WDF handle field is explicitly left null;
- transfer storage and completion snapshot are explicitly cleared;
- owner-ready is not assigned;
- initialization assignments are limited to none, model-ready, and faulted;
- authoritative invalid generation, operation sequence, and step constants are
  used;
- no WDF object creation, request formatting, request submission, completion
  registration, cancellation, target discovery, dynamic allocation, install,
  load, package, signing, device-query, USB/HID/IOCTL, wait, or delay runtime
  surface exists in the context code;
- `ChatpadFilter` remains unlinked and unmodified by the context module.

The guard passes in Debug and Release context compile-check runs.

## Follow-on attribute preparation

The owner remains a valid pre-object ordinary-storage record only.
[Offline KMDF Object-Attribute Preparation Checkpoint](OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md)
now implements caller-owned attribute builders for the future device-parented
lock/request and request-parented memory objects. That follow-on creates no WDF
object, does not publish owner-ready, and does not link into `ChatpadFilter`.
