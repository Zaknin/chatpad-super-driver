# ChatpadFilter live activation runtime

`ChatpadFilter` is an x64 KMDF device-specific lower filter for
`USB\VID_045E&PID_028E`. The INF limits attachment to that hardware ID and the
driver independently rejects any device whose hardware-ID multi-string does
not contain the same exact ID.

The physical Xbox filter lifecycle is authoritative and always fail-open with
respect to Chatpad functionality. VHF, activation, endpoint discovery, reads,
decoding, and keyboard submission are optional feature stages. Failure in any
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
pipe 0 handle. Every other internal request is forwarded unchanged to the
next-lower I/O target.

Only interface index 2, pipe index 0 (the Chatpad IN endpoint established by
the historical implementation) is opened for the driver's own reads.
Interface 0 and all normal controller traffic remain owned by `xusb22`.

## Activation and input

After PrepareHardware creates the USB target and the parent configuration URB
has established interface 2, D0 entry queues one passive-level activation work
item. An interlocked per-D0 consumption gate prevents duplicate activation.
The worker sends the six authoritative vendor control transfers in exact
sequence, with a one-second timeout for each transfer and the protocol's 12 ms
post-transfer delay. It validates NTSTATUS, byte counts, and the final `09 00`
response, stops on the first failure, and never retries automatically.

On successful activation, a separate passive work item performs bounded
250 ms synchronous reads from only the Chatpad pipe. The existing five-byte
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
the first valid input packet, the first eight decode/map failures, VHF emission
failures, input-loop stop, and cleanup.

## Build and package boundary

The project itself keeps WDK `SignMode` off. `tools/Build-Driver.ps1` produces
an unsigned SYS beneath `artifacts/`; packaging signs copied deliverables with
the already-authorized local development certificate. The driver must not be
installed by build or test scripts. Functional success requires a later manual
package upgrade and real controller/Chatpad test by the operator.
