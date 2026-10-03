# Virtual Xbox helper and independent observer

TASK 8L-C2R1 compiles the real adapter prepared in C2, retaining the replaceable
backend, bounded IPC helper, mock backend and separate read-only XInput observer.
No SDK context, real virtual controller, installer or driver was executed.

## Pinned dependency and license

External source: https://github.com/hifihedgehog/HIDMaestro at exact revision
`1c126ed4780322454391b7be782230b35b0810f6`; local `v1.10.1` tag resolves to this
revision and the reference checkout is clean. The literal root LICENSE is MIT,
copyright 2026 HIDMaestro Contributors, including its preserved preamble.
Source license SHA256: `FBA8DB4FFF568AC6A91E4C3100D1BE32D83DAE713D924EECB291182FFC11D885`.
No upstream implementation source or SDK binary is tracked in this repository.

C2R1 consumes the official external release DLL instead of building upstream's
payload-producing project. Release ZIP SHA256 matches GitHub's asset digest:
`DE5D0569F94229935523FA34F00136F597809F2E7760B783EDBCDD0258E145DC`.
DLL SHA256: `CA45EFE79C2406EB766C972F9DFEBC4BA80E33E95923D2DF4B49B8F470434E75`.
DLL identity is HIDMaestro.Core 1.10.1.0; release license text equals the pinned
source after newline normalization. This is release provenance, not an upstream
reproducible-build attestation.

`Prepare-Sdk.ps1` verifies clean pinned source/tag/license and fixed ZIP/DLL
hashes, then extracts only HIDMaestro.Core.dll, LICENSE and THIRD-PARTY-NOTICES
under ignored artifacts. The unmodified SDK includes embedded driver/tool,
USB/IP installer and profile resources. The MIT notice and third-party notices
(BSD 2-Clause USB/IP and BSD 3-Clause DsHidMini material) accompany redistribution.
No embedded payload is installed or executed in C2R1. Upstream projects/targets
are never invoked; they would build/embed drivers and download installers.

## Build and offline tests

C2's installed .NET9.0.318 could build the default mock helper but failed
NETSDK1045 for the real adapter. C2R1 installs official .NET10.0.401 into
`C:\Dev\tools\dotnet10` with Microsoft's [dotnet-install script](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script)
and `-NoPath`. Certificate generation, telemetry and first-use effects are
suppressed. Global runtime registration, PATH, trust and security are unchanged.
The real adapter targets net10.0-windows10.0.26100.0; Windows targeting restores
with the cleared-feed NuGet configuration without a workload installation.

```powershell
tools/ChatpadVirtualXbox/Prepare-Sdk.ps1 -ReferenceRepository artifacts/task-8lc1/hidmaestro-reference
tools/ChatpadVirtualXbox/Build.ps1 -Configuration Release -EnableHidMaestro -HidMaestroSdkPath artifacts/task-8lc2r1/virtual/sdk-dependency/HIDMaestro.Core.dll -DotnetPath C:/Dev/tools/dotnet10/dotnet.exe -ArtifactsDirectory artifacts/task-8lc2r1/virtual/real
tools/ChatpadVirtualXbox/Test-Helper.ps1 -Configuration Release -DotnetPath C:/Dev/tools/dotnet10/dotnet.exe -ArtifactsDirectory artifacts/task-8lc2r1/virtual/real
C:/Dev/tools/dotnet10/dotnet.exe artifacts/task-8lc2r1/virtual/real/bin/ChatpadVirtualXbox/release/ChatpadVirtualXbox.dll backend-status
```

Default builds retain net9.0 and the prior commands without new arguments;
`-ArtifactsDirectory` directs intermediates/binaries/reports to an ignored tree.
Build caps workers at two, verifies the exact pinned SDK hash for real builds,
and copies dependency notices beside the helper. `-SkipTests` supports root's
single final regression after focused development checks.

The focused real Release build has zero warnings/errors, 94 unit checks and
seven subprocess fixtures passing. C2's 85 checks are retained, adding six
common availability/lifecycle tests and three conditional adapter tests. The
default build has 91 unit checks. Repeated configurations do not multiply
distinct checks. Exhaustive stick-X/Y and trigger integer source-model checks
remain; those are not live SDK/XInput acceptance. Process fixtures cover mock
create/submit/disconnect/reconnect, unavailable backend, framing, finite idle
and partial-line deadlines, EOF and oversize input. Earlier failed C2 redirected
stdin cancellation evidence is retained; the bounded foreground waits on one
background blocking reader, never starting another reader after timeout.

## Availability gate and actual host result

`backend-status` is read-only and reports SDKCompiled, RuntimeReady and Reason,
plus contextConstructed=false/liveDeviceCreated=false. It returns 0 for matching
runtime package bytes, 3 for unavailable. It uses SDK resource streams and
Driver Store file hashes only, never HMContext or an upstream presence API.
Both installed amd64 hidmaestro.inf/HIDMaestro.dll and
hidmaestro_xusb.inf/HMXInput.dll must byte-match the official DLL's embedded
resources. Missing payload, missing files, mismatch, unsupported architecture
or access error fails closed. Package presence does not prove normal-Windows
load/signature acceptance; C3 must verify that separately.

The C2R1 host reports SDKCompiled=true, RuntimeReady=false, exit3: pinned
hidmaestro.inf runtime is not installed or does not match. A real adapter
instance in the subprocess test returns backend_unavailable without creating
an SDK context. Runtime-present and runtime-absent mocks prove factory ordering.
Installing/authorizing a compatible real HIDMaestro runtime is an external
prerequisite, explicitly outside C2R1's permitted live changes.

GuardedBackend probes before any factory call, then requires explicit live
permission, then constructs the SDK adapter. Mock-present tests use MockBackend
as the factory and never construct HMContext. Re-check installed packages and
ordinary-Windows trust before separately authorized C3. SDK context construction
schedules resource extraction and service work, and CreateController can
perform automatic deployment if installation state changes. The guard cannot
eliminate this later SDK race; the helper never calls InstallDriver and does
not claim installer isolation. All these side effects require explicit future
experiment scope. Select only xbox-360-wired and reject USB/IP profiles.

The local SDK is not a globally registered runtime. A future native launch of
the real helper apphost must inherit process-local
`DOTNET_ROOT=C:\Dev\tools\dotnet10`, or use a separately verified runtime
installation. C2R1 does not change system environment variables.

## Adapter and IPC contract

IVirtualXboxController exposes Create, SubmitState, SetRumbleCallback,
Disconnect and Dispose. The real adapter uses only public HMContext,
HMController, HMGamepadState, StandardAxes and output-event APIs. No private
shared-memory ABI is reproduced. SDK stdout is redirected to stderr so it does
not corrupt the JSON protocol. Parent watchdogs remain necessary for blocking
SDK calls; the managed request deadline cannot guarantee their cancellation.

```text
ChatpadVirtualXbox.exe helper --backend mock --duration-ms 30000 --idle-ms 1000
ChatpadVirtualXbox.exe helper --backend hidmaestro --duration-ms 30000 --idle-ms 1000
```

Only a future authorized run may add --allow-live-virtual. Without a matching
runtime, that flag still cannot pass the availability gate.

```json
{"id":1,"op":"create"}
{"id":2,"op":"submit","buttons":4096,"leftTrigger":255,"rightTrigger":0,"lx":0,"ly":0,"rx":0,"ry":0}
{"id":3,"op":"disconnect"}
{"id":4,"op":"quit"}
```

UTF-8 LF lines are bounded to4096 bytes and10000 requests/120seconds. ID is
nonnegative int32, buttons uint16, triggers uint8, sticks int16. All state fields
are mandatory; duplicate/unknown fields, nonintegers and range errors fail.
One acknowledgement follows each request; callback event lines carry uint16
leftMotor/rightMotor. EOF/quit releases output. Deadline exit4, argument exit2,
normal quit/EOF exit0. Unavailable is an explicit failed acknowledgement.

State mapping retains XInput semantics, opposing D-pad directions become
neutral, and Y inversion/upward rounding retain integer source-model values.
Guide is submitted through the public mask but ordinary XInputGetState excludes
Guide. Only the pinned source=XInput/reportId0/five-byte `00 00 lo hi 00` rumble
fixture is accepted; motor bytes multiply by257. Other output formats log stderr
and never invent physical output. Real rumble/Guide/input remain untested.

## Independent read-only observer

```text
ChatpadVirtualXbox.exe snapshot --slot 0
ChatpadVirtualXbox.exe observe --slot 1 --expect-file state.json --timeout-ms 1000 --poll-ms 10
```

Expected JSON contains the seven submit state fields without ID/op. Explicit
slot0..3 is mandatory; no first-connected fallback. Documented XInputGetState
only, no XInputSetState. Return code/packet/state/deadline are recorded; mismatch
exit3 and Guide-positive expectations are rejected. identityProven=false until
separate virtual-instance/slot association. C3 must census all slots, prove
physical XInput disappearance, correlate the intended virtual instance/slot,
and submit a distinct known state. Neutral matching alone proves no origin.
