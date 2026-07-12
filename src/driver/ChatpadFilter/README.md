# ChatpadFilter live activation runtime

`ChatpadFilter` is an x64 KMDF device-specific lower filter for
`USB\VID_045E&PID_028E`. The INF limits attachment to that hardware ID and the
driver independently rejects any device whose hardware-ID multi-string does
not contain the same exact ID.

## USB transport

The Microsoft `xusb22` function driver owns the normal Xbox controller path.
The filter therefore does not select a second configuration and does not
replace or intercept controller reports. It observes the parent's
`URB_FUNCTION_SELECT_CONFIGURATION` request, passes that same URB to
`WdfUsbTargetDeviceSelectConfig`, and completes the original request with the
result. This lets KMDF cache the configuration and pipe handles which the
parent selected. Every other internal request is forwarded unchanged to the
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

VHF exposes those reports as a virtual keyboard. D0 exit, release, cancellation,
read failure, and cleanup all force an all-keys-up report so removal cannot
leave a stuck key. Work items are flushed before the hardware epoch is released.

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
