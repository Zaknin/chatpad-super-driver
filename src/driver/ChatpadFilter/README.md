# ChatpadFilter live activation runtime

`ChatpadFilter` is an x64 KMDF device-specific lower filter for
`USB\VID_045E&PID_028E`. The INF limits attachment to that hardware ID and the
driver independently rejects any device whose hardware-ID multi-string does
not contain the same exact ID.

The physical Xbox filter lifecycle is authoritative and always fail-open with
respect to Chatpad functionality. VHF, activation, endpoint discovery,
keep-alive, reads, decoding, and keyboard submission are optional feature stages. Failure in any
of them disables or degrades only Chatpad output, records the first failing
stage, and still returns success from the physical PrepareHardware/D0 path.
Only inability to attach or forward the physical filter safely may fail Xbox
startup.

## USB transport

The Microsoft `xusb22` function driver owns the normal Xbox controller path.
The filter therefore does not select a second configuration and does not
replace or intercept controller reports. It forwards the parent's
`URB_FUNCTION_SELECT_CONFIGURATION` and select-interface requests unchanged,
observes their completion, and retains only the already-selected interface 2
pipe 0 handle plus the interface 0 input-pipe identity used solely as a
readiness signal. Every other internal request is forwarded unchanged to the
next-lower I/O target.

Only interface index 2, pipe index 0 (the Chatpad IN endpoint established by
the historical implementation) is used for the driver's own reads. Interface
0 and all normal controller traffic remain owned by `xusb22`; the filter only
observes completion of the first successful parent input request on its exact
configured pipe.

## Activation and input

After the parent configuration URB has established interface 2, D0 entry arms
activation but does not consume it. The filter waits until a successful,
non-empty xusb22 request completes on the configured interface-0 controller
input pipe, proving that normal controller initialization and traffic are live;
only then does it queue one passive-level activation work item. An interlocked
per-D0 consumption gate prevents duplicate activation.
The worker sends the six authoritative vendor control transfers as generic
raw-setup control URBs, matching the retained working driver's transfer form.
Endpoint zero uses a null pipe handle plus the mandatory
`USBD_DEFAULT_PIPE_TRANSFER` flag; the filter does not select or claim the
xusb22-owned configuration. Each transfer has a one-second timeout and the
protocol's 12 ms post-transfer delay. The first
three legacy `40/A9` preamble requests are
required even though the controller is documented and live-observed to stall
them. The first two-byte read probe is also live-observed to stall before the
activation write. Only a zero-byte `USBD_STATUS_STALL_PID` on those exact four
steps is accepted. Any other pre-write failure, every activation-write failure,
and every final-probe failure is fatal to the optional activation attempt. The
worker validates byte counts and the final `09 00` response and never retries
automatically.

On successful activation, a separate passive work item immediately sends the
retained working runtime's zero-length interface keep-alive and alternates
`41 00 1F 00 02 00 00 00` with `41 00 1E 00 02 00 00 00` every second using
the same endpoint-zero default-pipe transport. A failed keep-alive disables
only the optional Chatpad path. Between scheduled keep-alives, the worker
performs bounded 250 ms synchronous reads from only the Chatpad pipe. The existing five-byte
parser validates each packet. `ChatpadKeyboardHid` maps the known raw keys and
Shift modifier to standard boot-keyboard usages, suppresses duplicate reports,
and preserves two-key make/break state.

## Supported VHF source and isolated keyboard lifecycle

Microsoft supports a KMDF filter device as a VHF HID source. `ChatpadFilter`
uses its physical filter `WDFDEVICE` as that source, while the INF orders the
in-box `vhf.sys` below it as required by VHF. The previous `ChatpadFilter, vhf`
legacy list produced the opposite live relationship and `VhfCreate` returned
`STATUS_NOT_SUPPORTED`; version 1.0.5 uses `vhf, ChatpadFilter`.

The VHF keyboard remains a logically independent optional sub-lifecycle even
though the supported source context is the filter WDFDEVICE. Decoded reports
cross a fixed eight-report queue to a dedicated passive keyboard worker. The
queue never blocks the input or Xbox path: unavailable VHF drops output,
overflow disables the optional feature, and teardown flushes pending reports.
VHF is started only after creation, and is deleted only after activation,
input, keyboard, and diagnostic workers are flushed. D0 exit, release,
cancellation, read failure, and cleanup force an all-keys-up report before VHF
teardown so removal cannot leave a stuck key. There is no retry loop.

Diagnostics are deliberately bounded: device match, USB target/configuration,
D0 activation queue/start, every activation step, activation completion/failure,
the first keep-alive result and the first eight keep-alive attempt-count updates,
the first valid input packet, the first eight decode/map failures, VHF emission
failures, input-loop stop, and cleanup.

## Build and package boundary

The project itself keeps WDK `SignMode` off. `tools/Build-Driver.ps1` produces
an unsigned SYS beneath `artifacts/`; packaging signs copied deliverables with
the already-authorized local development certificate. The driver must not be
installed by build or test scripts. Functional success requires a later manual
package upgrade and real controller/Chatpad test by the operator.
