# Chatpad Initialization and Status Evidence Audit

## 1. Scope and safety

This is a documentation-only audit of immutable source beneath
`legacy/source_release_0_0_4a/`. It distinguishes executable call paths from
comments, internal structures from USB setup fields, and setup fields from data
payloads. No legacy file was modified or executed. No device was enumerated or
accessed, and no USB, HID, IOCTL, driver, build, installation, signing,
packaging, deployment, or loading action was performed.

The nine field classifications used below are the classifications required by
the audit: confirmed transmitted payload byte; confirmed USB
setup/control-request field; internal structure field; internal enum, flag,
state, or sentinel; buffer initialization or default zero; comparison against
received data; comment-only claim; unrelated occurrence; and ambiguous or
unresolved.

## 2. Executive conclusion

1. **Is `0x90` proven to be a transmitted payload byte?** No. Its only legacy
   occurrence is in a comment beside an unreferenced `initCode[2]` member.
2. **Is `0x90` proven to be a USB setup field?** No. It is never assigned to
   `bmRequestType`, `bRequest`, `wValue`, `wIndex`, or `wLength`.
3. **What is initialization-related `0x00`?** Several different things. The
   second byte of the actually supplied activation payload is confirmed as
   `0x00` (`09 00`). Other zeros are confirmed setup-field values, including
   `wValue == 0`, `wLength == 0`, and later `bRequest == 0`; still others only
   clear buffers or initialize flags. The `00` beside `90` is comment-only.
4. **Is there a complete confirmed initialization sequence?** No. The entire
   legacy routine is traceable, but its first three requests are described as
   unexplained, expected to stall, and required only by observation. The
   routine also contains test LED/controls operations. This proves a legacy
   call sequence, not a complete, semantically validated protocol sequence.
5. **Is there a confirmed acknowledgement or response?** No. Two control-IN
   transfers request two bytes, but the bytes are only logged and never
   validated. API completion is checked; acknowledgement semantics are not.
6. **Is there a confirmed status or keepalive packet format?** No. The source
   labels alternating no-data control requests with `wValue` `001f` and `001e`
   as keep-alive requests, but it does not parse a response or prove their
   device semantics. Received packets beginning with `f0` are ignored, and
   their meaning remains unknown.
7. **Is retry behavior confirmed?** No initialization retry exists. A TODO
   proposes trying other codes. Periodic keep-alive-labeled requests repeat
   during the main loop, but the loop stops on the first failure.
8. **Is successful initialization objectively verified?** No. The filter sets
   `msInitFinished` when USB configuration selection succeeds, and the user
   routine treats successful API completion as progress. `chatpadInitFinished`
   is never set true or read. No response content or device-ready condition is
   validated.
9. **Smallest safe next behavior:** represent the fully confirmed activation
   control requests as neutral declarative data and test their construction
   offline. Do not label the sequence successful initialization, decode a
   response, or add live USB access.

## 3. Source files and symbols examined

- `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h`: IOCTL macros,
  `XBOX_CONTROLLER_INTERFACE`, `CHATPAD_INIT_REQUEST`, `CHATPAD_REQUEST`.
- `legacy/source_release_0_0_4a/chatpad_control/chatpad_cmdline.cpp`: `main`.
- `legacy/source_release_0_0_4a/chatpad_control/chatpad_control_code.cpp`:
  `ExecuteControlIOCTL`, `SendControlRequest`, `HandleChatpadData`,
  `ChatpadReadFunction`, `LaunchWorkerThreads`, `InitChatpad`, and
  `ChatpadControlMainLoop`.
- `legacy/source_release_0_0_4a/chatpad_control/chatpad_control.h`:
  `ChatpadStateData::previousChatpadRawData`.
- `legacy/source_release_0_0_4a/filter/chatpad_filter.h`: timeout constants and
  `DEVICE_CONTEXT` initialization flags.
- `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp`: device-context
  defaults, configuration-selection handling, disabled completion heuristic,
  and `ChatpadFilterIOCTLHandler` control-transfer construction.

Repository-wide targeted searches found only one `0x90` occurrence and no
reference to `CHATPAD_INIT_REQUEST`, `initRequest`, or `initCode` outside their
declarations.

## 4. `0x90` occurrence inventory

The only occurrence is
`include/chatpad_filter_ioctl.h:132-137`. Line 134 says a 16-bit init code is
“like `0x90 0x00`”; line 135 immediately questions whether it is correct. The
structure contains `UCHAR initCode[2]`, but neither byte is initialized by the
declaration. The structure is nested in `CHATPAD_REQUEST` at lines 141-150;
neither structure is referenced elsewhere in the legacy tree.

Classification: **comment-only claim** for `0x90`; **internal structure field**
for `initCode[2]`; not a payload, report ID, interface number, IOCTL field, or
USB setup field. Any intended byte order or transmission path is unresolved.

## 5. Initialization-related `0x00` occurrence inventory

| Occurrence | Classification | Finding |
|---|---|---|
| `chatpad_filter_ioctl.h:132-137`, comment `90 00` | Comment-only claim | No assignment or use exists. |
| `chatpad_control_code.cpp:790-794`, IOCTL buffers | Buffer initialization or default zero | Allocation and receive buffers are cleared before fields/data are written. The unused allocation tail is not sent. |
| `chatpad_control_code.cpp:4096-4098`, `OVERLAPPED` | Buffer initialization or default zero | Host bookkeeping only. |
| `chatpad_control_code.cpp:4165-4169`, send/receive arrays | Buffer initialization or default zero | Host buffers are cleared; only explicit lengths are later supplied. |
| `chatpad_control_code.cpp:4183-4185`, `0000` length | Confirmed USB setup/control-request field | `wLength == 0`; no data-stage payload is supplied. |
| `chatpad_control_code.cpp:4192-4194`, `0000` value | Confirmed USB setup/control-request field | `wValue == 0` on a two-byte control-IN request. |
| `chatpad_control_code.cpp:4209-4213`, payload `09 00` | Confirmed transmitted payload byte | The second of two explicit extra-data bytes is `00`. |
| `chatpad_control_code.cpp:4211-4212`, `0000` value | Confirmed USB setup/control-request field | `wValue == 0` on the two-byte control-OUT activation request. |
| `chatpad_control_code.cpp:4218-4221`, cleared receive buffer and `0000` value | Buffer default plus confirmed setup field | The buffer is reset; `wValue == 0`; returned bytes are not compared. |
| `chatpad_control_code.cpp:4244-4249`, `00` request and zero lengths | Confirmed USB setup/control-request fields | `bRequest == 0`, `wLength == 0`; these LED/test calls have no payload. |
| `chatpad_control_code.cpp:4760-4768`, `00` request and zero lengths | Confirmed USB setup/control-request fields | Keep-alive-labeled calls use `bRequest == 0`, `wLength == 0`; no payload. |
| `chatpad_filter.cpp:330-332`, false flags | Internal enum, flag, state, or sentinel | Initial software state; not device data. |
| `chatpad_filter.cpp:2093-2099`, `bufferData` fill | Buffer initialization or default zero | Temporary completion-inspection buffer only. |
| `chatpad_filter.cpp:2124-2142`, comment `05 03 00` | Comment-only claim | Described as a platform-specific observed final sequence; it is not the disabled comparison, which checks `01 03 06`. |

The repeated `0002` in activation requests is not a two-byte payload. Depending
on call position it is `wLength == 2` or `wIndex == 2`. The setup mapping in
the next section disambiguates it.

## 6. Confirmed initialization call path

1. `chatpad_cmdline.cpp:26-46`: command-line `main` sleeps five seconds unless
   `--nodelay` is present, then calls `ChatpadControlMainLoop`.
2. `chatpad_control_code.cpp:4626-4718`: the main loop initializes globals,
   loads configuration, opens the controller and virtual devices, and calls
   `InitChatpad` once if all prior operations report success.
3. `chatpad_control_code.cpp:4079-4147`: `InitChatpad` serializes an
   `IOCTL_CHATPAD_IS_MS_INIT_DONE` query, waits for overlapped completion, and
   fails if it does not complete successfully.
4. `chatpad_filter.cpp:2913-2934`: the filter returns success only when
   `usbConfigSelected` and `msInitFinished` are true. However,
   `chatpad_filter.cpp:2509-2517` sets both true after USB configuration
   selection; it does not validate a device initialization response.
5. `chatpad_control_code.cpp:4163-4222`: `InitChatpad` makes three unexplained
   control-OUT requests, one control-IN request, one control-OUT request with
   payload `09 00`, and a second identical control-IN request. The two IN
   buffers are logged, not parsed.
6. `chatpad_control_code.cpp:4225-4249`: the same routine performs a controls
   endpoint light test and sends five no-data LED control requests. These are
   source-confirmed side effects of the legacy routine, not proof of required
   initialization semantics.
7. `chatpad_control_code.cpp:4739-4775`: after `InitChatpad` returns success,
   worker reads begin and the main loop alternates two keep-alive-labeled
   no-data control requests until failure or shutdown.

The chain is complete as a software call path. It stops short of proving a
complete device protocol because the response values and ready state are never
validated.

## 7. USB control-request field mapping

`SendControlRequest` serializes an internal IOCTL buffer at
`chatpad_control_code.cpp:796-816`: byte 0 is the caller’s interface selector;
bytes 1-8 are `bmRequestType`, `bRequest`, little-endian `wValue`, `wIndex`, and
`wLength`; bytes 9 onward are an optional data-stage payload. The filter copies
only bytes 1-8 into `WDF_USB_CONTROL_SETUP_PACKET.Generic.Bytes`
(`chatpad_filter.cpp:3014-3018`) and supplies bytes 9 onward as the data stage
for host-to-device requests (`3027-3042`). For device-to-host requests it uses
the IOCTL output buffer (`3018-3025`).

| Legacy step | `bmRequestType` | `bRequest` | `wValue` | `wIndex` | `wLength` | Data stage |
|---|---:|---:|---:|---:|---:|---|
| Mystery 1 | `40` | `a9` | `a30c` | `4423` | `0000` | none |
| Mystery 2 | `40` | `a9` | `2344` | `7f03` | `0000` | none |
| Mystery 3 | `40` | `a9` | `5839` | `6832` | `0000` | none |
| Probe/read 1 | `c0` | `a1` | `0000` | `e416` | `0002` | device to host, two requested bytes |
| Activation/write | `40` | `a1` | `0000` | `e416` | `0002` | host to device: `09 00` |
| Probe/read 2 | `c0` | `a1` | `0000` | `e416` | `0002` | device to host, two requested bytes |
| Keep-alive-labeled A | `41` | `00` | `001f` | `0002` | `0000` | none |
| Keep-alive-labeled B | `41` | `00` | `001e` | `0002` | `0000` | none |

All values above are **confirmed USB setup/control-request fields**, except the
explicit `09 00` data stage. Direction follows bit 7 of `bmRequestType`, which
the filter itself tests at lines 3018-3035.

The `MAIN_INTERFACE`/`CHATPAD_INTERFACE` selector is an **internal enum field**
placed at IOCTL byte 0. The filter does not use it to select an interface; it
copies setup bytes beginning at byte 1 and comments that the synchronous
transfer works without a specific interface (`chatpad_filter.cpp:3014-3017,
3054-3061`). Thus enum value 2 is not proven to be a transmitted interface
number. No non-default endpoint is selected for these control requests; the
source calls the device-level WDF control-transfer API.

## 8. Payload evidence

The only confirmed initialization data-stage payload is two bytes: `09 00`.
`InitChatpad` assigns those values at `chatpad_control_code.cpp:4209-4210` and
passes the buffer with extra length 2 at lines 4211-4212. `SendControlRequest`
appends exactly those two bytes after the eight setup bytes at lines 812-816,
and the filter selects bytes after IOCTL offset 8 as host-to-device data at
lines 3027-3034.

The first three requests have `wLength == 0` and no extra buffer, so they have
no confirmed payload. The two control-IN requests provide no outgoing payload;
they request two returned bytes. `90 00` is not payload evidence.

## 9. Trigger and timing evidence

- Default command-line startup adds a five-second delay; `--nodelay` removes it
  (`chatpad_cmdline.cpp:34-46`). This is process startup timing, not protocol
  timing.
- Initialization is attempted once after all required handles open
  (`chatpad_control_code.cpp:4654-4718`).
- Every `SendControlRequest` call sleeps 12 ms unconditionally, including after
  failure (`chatpad_control_code.cpp:829-840`). The comment says closely spaced
  light commands appeared problematic; this is observed implementation policy,
  not a proven device minimum.
- The filter applies a ten-second WDF timeout to each synchronous control
  transfer (`filter/chatpad_filter.h:63-64`; `filter/chatpad_filter.cpp:3044-3051`).
- The Microsoft-init query can wait indefinitely in `GetOverlappedResult(...,
  TRUE)` (`chatpad_control_code.cpp:4116-4129`). General control IOCTLs wait
  indefinitely for either completion or worker shutdown (`659-679`).
- The keep-alive-labeled loop adds a one-second sleep after each request
  (`chatpad_control_code.cpp:4757-4774`), in addition to the function’s 12 ms
  sleep.

## 10. Completion and error-handling evidence

`ExecuteControlIOCTL` validates handles, serializes access with a mutex, waits
for overlapped completion, calls `GetOverlappedResult`, and returns failure on
an unsuccessful IOCTL (`chatpad_control_code.cpp:590-742`). The filter checks
the synchronous WDF call’s `NTSTATUS`, uses a ten-second timeout, and completes
the user IOCTL with that status and `bytesTransferred`
(`filter/chatpad_filter.cpp:3044-3075,3273-3279`).

The three mystery calls at `chatpad_control_code.cpp:4183-4185` discard their
return values. Their own comments say stalls/failures are expected, so those
failures cannot prevent later activation calls. Subsequent IN/OUT/IN requests
do gate on return status, but returned bytes are only logged. Because receive
buffers are pre-zeroed, the log can show zero bytes without proving that two
bytes arrived; the code does not guard the logging with a transferred-length
check.

If the control device is unavailable, the filter immediately completes the
IOCTL with `STATUS_INTERNAL_ERROR` (`filter/chatpad_filter.cpp:2896-2910`). A
failed chatpad read ends the worker and cancels its pending I/O
(`chatpad_control_code.cpp:3808-3817,3909-3929`). A failed periodic control
request sets the main-loop finish flag (`4760-4774`).

## 11. Status, polling, or keepalive evidence

There are three distinct mechanisms, none of which proves a status packet
format:

1. `IOCTL_CHATPAD_IS_MS_INIT_DONE` queries only the filter’s internal flag.
   It transfers no payload or returned status byte (`chatpad_control_code.cpp:
   4106-4114`; `filter/chatpad_filter.cpp:2918-2929`).
2. The main loop repeatedly sends control requests with setup `41 00 001f 0002
   0000` and `41 00 001e 0002 0000`, calling them keep-alive requests
   (`chatpad_control_code.cpp:4735-4774`). They contain no payload and request
   no response. Their purpose is therefore a legacy comment/behavior claim,
   not independently verified semantics.
3. The read worker maintains two pending 32-byte chatpad endpoint reads
   (`chatpad_control_code.cpp:3732-3834`). Packets whose first byte is `f0` are
   excluded from input handling and previous-packet state
   (`3372-3434,3708-3717`; `chatpad_control.h:430-433`). The code says it does
   not know what they do. `f0` is therefore a **comparison against received
   data** with unresolved meaning, not a confirmed keepalive or status type.

No periodic response parser, acknowledgement comparison, readiness transition,
or status/keepalive packet schema was found.

## 12. Internal structures versus wire format

`CHATPAD_INIT_REQUEST.initCode[2]` is only an internal field declaration. It is
not populated, passed to `SendControlRequest`, copied into a setup packet, or
written to an endpoint. `CHATPAD_REQUEST` and its containing buffer are also
unreferenced outside the header.

By contrast, the nine-byte base buffer created by `SendControlRequest` is an
internal user-to-filter IOCTL representation. Byte 0 is internal-only; bytes
1-8 are transformed by copying into a WDF USB setup packet; optional bytes 9+
are the control transfer’s data stage. Calling all nine bytes a device packet
would collapse three different layers and is incorrect.

The `msInitFinished`, `chatpadInitFinished`, and `usbConfigSelected` members are
internal flags. None is a device status byte. `chatpadInitFinished` is
initialized false and never used again.

## 13. Confirmed facts

- `0x90` appears once, in a tentative comment attached to unused declarations.
- The legacy activation routine supplies `09 00` as a two-byte host-to-device
  data-stage payload.
- The six activation setup packets and two alternating keep-alive-labeled setup
  packets are exactly constructible from source.
- Setup completion status is propagated through the filter and user utility.
- Two control-IN operations request two bytes each, but the data is not parsed.
- USB configuration selection sets the internal Microsoft-init flag true.
- There is no initialization retry and no assignment setting
  `chatpadInitFinished` true.

## 14. Inferred behavior

- The author intended the `09 00` write and adjacent reads to activate Chatpad
  data flow. That intent is strong from comments and placement, but successful
  activation is not objectively tested.
- The alternating `001f`/`001e` requests were believed to keep the Chatpad
  active. Repetition is confirmed; purpose is not.
- The two control-IN reads may have been intended as a handshake or status
  observation. Since their values are neither compared nor stored, their
  semantic role is unresolved.

These inferences must not become API names, ready states, response classes, or
runtime policy without additional evidence.

## 15. Unresolved questions

- What, if anything, was `90 00` intended to represent?
- What do the three `40/a9` requests do, and are their stalls required?
- What exact two bytes can the `c0/a1` reads return, and do they acknowledge
  activation?
- Why is `wIndex` `e416`, and is that controller-specific?
- Does payload `09 00` work across devices, firmware, or controller revisions?
- What do received `f0` messages mean?
- Do `001f` and `001e` have keepalive semantics, and is alternating required?
- What condition objectively proves the Chatpad is ready to send key data?
- Is the post-first-read `001b` backlight request required for data flow, as
  the comment claims, or only for lighting?

## 16. Contradictions or conflicting implementations

- The unused header comment proposes `90 00`, while executable activation code
  sends `09 00`.
- A disabled heuristic sought received `01 03 06`; a nearby comment says one
  Vista system ended with `05 03 00`; active code ignores both and marks
  Microsoft initialization complete on configuration selection
  (`filter/chatpad_filter.cpp:2124-2142,2509-2517`).
- The IOCTL buffer carries an interface enum, but the filter does not select
  that interface for the control transfer (`chatpad_filter.cpp:3014-3017,
  3054-3061`).
- Comments call two periodic requests keep-alives, but no response or readiness
  effect is checked.

## 17. Legacy defects not to reproduce

- Do not treat USB configuration selection as proof of device initialization.
- Do not retain dead request structures or tentative literals as protocol fact.
- Do not ignore failures from prerequisite requests.
- Do not log zero-filled receive buffers as responses without validating the
  transferred length.
- Do not use indefinite waits without explicit timeout/cancellation policy.
- Do not combine activation, controller-light tests, LED state changes, and
  worker startup into one success result.
- Do not pass an interface selector that the receiving layer silently ignores.
- Do not infer packet semantics from names such as “keep-alive” or from an
  ignored `f0` prefix.

## 18. Safe next implementation boundary

**Recommendation: represent the confirmed control requests as a neutral
declarative structure and test their construction offline.**

The next task may encode only the six activation setup tuples and the confirmed
`09 00` payload, with tests that preserve direction, little-endian fields,
length, and absence/presence of a data stage. Names should describe ordering or
raw fields, not “ready,” “acknowledged,” or “success.” The three mystery
requests should remain explicitly unexplained. Do not add a response classifier
because no confirmed response form exists. Do not add transport, live USB,
driver integration, retries, keepalive policy, or semantic key mappings.

## 19. Evidence matrix

| Relative legacy path | Symbol and lines | Literal/expression | Field classification | Direction | Confidence | Explanation |
|---|---|---|---|---|---|---|
| `include/chatpad_filter_ioctl.h` | `CHATPAD_INIT_REQUEST`, 132-137 | comment `90 00`; `initCode[2]` | Comment-only claim; internal structure field | internal only | confirmed | Only `90` occurrence; no initializer or use. |
| `include/chatpad_filter_ioctl.h` | `CHATPAD_REQUEST`, 141-150 | `initRequest` union member | Internal structure field | internal only | confirmed | Declaration only; no call path. |
| `include/chatpad_filter_ioctl.h` | IOCTL macros, 23-33 | functions 2049/2050 | Internal enum, flag, state, or sentinel | caller to driver | confirmed | Internal API for flag query and control transfer. |
| `include/chatpad_filter_ioctl.h` | `XBOX_CONTROLLER_INTERFACE`, 93-108 | `0`, `1`, `2` | Internal enum, flag, state, or sentinel | caller to driver | confirmed | IOCTL byte 0; not copied into USB setup. |
| `chatpad_control/chatpad_cmdline.cpp` | `main`, 26-46 | `Sleep(5000)` | Unrelated occurrence | internal only | confirmed | Startup delay, bypassed by `--nodelay`; not protocol data. |
| `chatpad_control/chatpad_control_code.cpp` | `SendControlRequest`, 790-816 | zero fills; setup bytes; extra bytes | Buffer default; confirmed setup fields; confirmed payload | caller to driver | confirmed | Separates internal selector, setup, and optional data. |
| `chatpad_control/chatpad_control_code.cpp` | `SendControlRequest`, 818-840 | IOCTL 2050; `Sleep(12)` | Internal request; timing policy | caller to driver | confirmed | Completion result returned; unconditional delay. |
| `chatpad_control/chatpad_control_code.cpp` | `InitChatpad`, 4096-4147 | init-done IOCTL; zero-length buffers | Internal flag query; buffer default zero | caller to driver | confirmed | Successful IOCTL is treated as permission to proceed. |
| `filter/chatpad_filter.cpp` | configuration path, 2509-2517 | `msInitFinished = TRUE` | Internal enum, flag, state, or sentinel | internal only | confirmed | Set on configuration selection, not a response. |
| `filter/chatpad_filter.cpp` | disabled completion check, 2124-2142 | `01 03 06`; comment `05 03 00` | Comparison against received data; comment-only claim | device/lower stack to driver | confirmed | Comparison is compiled out; meanings unresolved. |
| `filter/chatpad_filter.cpp` | `ChatpadFilterIOCTLHandler`, 2913-2934 | booleans; no buffers | Internal enum, flag, state, or sentinel | driver to user mode | confirmed | IOCTL success/failure exposes internal flags only. |
| `chatpad_control/chatpad_control_code.cpp` | `InitChatpad`, 4183-4185 | three `40 a9` tuples, length zero | Confirmed USB setup/control-request fields | driver to lower stack/device | confirmed | No payload; return values ignored; purpose unresolved. |
| `chatpad_control/chatpad_control_code.cpp` | `InitChatpad`, 4192-4194 | `c0 a1 0000 e416 0002` | Confirmed USB setup/control-request fields | device/lower stack to driver | confirmed | Requests two bytes; values only logged. |
| `chatpad_control/chatpad_control_code.cpp` | `InitChatpad`, 4209-4213 | payload `09 00`; `40 a1 0000 e416 0002` | Confirmed transmitted payload byte; confirmed setup fields | driver to lower stack/device | confirmed | Only proven initialization payload. |
| `chatpad_control/chatpad_control_code.cpp` | `InitChatpad`, 4216-4222 | second `c0/a1` read | Confirmed USB setup/control-request fields | device/lower stack to driver | confirmed | Returned bytes are not compared. |
| `filter/chatpad_filter.cpp` | `ChatpadFilterIOCTLHandler`, 3014-3061 | copy 8 setup bytes; bytes 9+ data | Confirmed USB setup/control-request field | driver to lower stack/device | confirmed | WDF control transfer carries setup and optional data. |
| `filter/chatpad_filter.cpp` | completion, 3062-3075, 3273-3279 | `apiStatus`, `bytesTransferred` | Internal enum, flag, state, or sentinel | driver to user mode | confirmed | API status is checked; response semantics are not. |
| `chatpad_control/chatpad_control_code.cpp` | main loop, 4757-4774 | `41 00 001f/001e 0002 0000` | Confirmed USB setup/control-request fields | driver to lower stack/device | confirmed | Periodic no-data requests; keepalive purpose inferred from comments. |
| `chatpad_control/chatpad_control_code.cpp` | `ChatpadReadFunction`, 3732-3929 | two pending 32-byte reads | Internal state/operation | device/lower stack to driver | confirmed | Continuous endpoint polling; exits on I/O failure. |
| `chatpad_control/chatpad_control_code.cpp` | `HandleChatpadData`, 3417-3434, 3708-3717 | `readBuffer[0] != f0` | Comparison against received data | device/lower stack to driver | confirmed | `f0` packets are ignored; meaning unresolved. |
| `filter/chatpad_filter.h` | `DEVICE_CONTEXT`, 106-112 | three booleans | Internal enum, flag, state, or sentinel | internal only | confirmed | Not wire status; Chatpad-init flag is unused. |
