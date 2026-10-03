# Virtual Xbox helper and independent observer

TASK 8L-C2 prepares a replaceable backend, a bounded managed IPC helper and a
separate read-only XInput observer. Default builds contain deterministic mock
and unavailable backends. They do not contain HIDMaestro, a driver payload or
an installer. No real virtual controller was created during C2.

## Pinned dependency and license

HIDMaestro external dependency:
`https://github.com/hifihedgehog/HIDMaestro`, revision
`1c126ed4780322454391b7be782230b35b0810f6`, inspected `v1.10.1`.
The literal root `LICENSE` was read. It is MIT, copyright
`2026 HIDMaestro Contributors`; retain its copyright/permission notice when
redistributing copies or substantial portions. Its religious preamble is
preserved verbatim in `tools/ChatpadVirtualXbox/UPSTREAM-LICENSE.txt`.
SHA-256: `FBA8DB4FFF568AC6A91E4C3100D1BE32D83DAE713D924EECB291182FFC11D885`.
No upstream implementation source or SDK binary is copied into this project.
`upstream.json` records provenance. A future external SDK DLL must have
independently verified provenance from this revision; supplying a DLL path
alone does not verify its provenance.

The upstream SDK project targets `net10.0-windows10.0.26100.0`. The installed
SDK is `9.0.318`. Conditional real-adapter compilation was attempted and
failed `NETSDK1045`; it remains uncompiled/unverified. The build does not
reference the upstream project: that project builds/embeds driver payload,
signing tools and downloaded USB/IP installers. Never invoke it as a routine
helper dependency build. Upstream `THIRD-PARTY-NOTICES.txt` also describes
BSD-2-Clause USB/IP binaries and other profile dependencies; external SDK
redistribution must retain all applicable notices. No such payload is
redistributed in the C2 default package.

## Offline build and tests

```powershell
tools/ChatpadVirtualXbox/Build.ps1 -Configuration Release
tools/ChatpadVirtualXbox/Build.ps1 -Configuration Debug
tools/ChatpadVirtualXbox/Test-Helper.ps1 -Configuration Release
tools/ChatpadVirtualXbox/Test-Helper.ps1 -Configuration Debug
```

These use installed .NET 9 and a NuGet configuration with no package sources;
there are no package dependencies. All intermediate files, binaries and test
reports go under ignored `artifacts/task-8lc2/virtual/`. The build script
disables .NET first-run certificate generation and telemetry.

Each configuration passes 85 deterministic tests and 7 subprocess fixtures.
The tests cover create/submit/reconnect/disconnect/unavailable, callback
lifetime, every supported button and hat combination, strict request parsing,
strict rumble source/report/length/reserved-byte validation, observer slots,
return codes and deadlines. Exhaustive source-model checks cover 65,536
stick-X values, 65,536 stick-Y values and 256 trigger values. They model the
pinned SDK's integer conversion; they are not live SDK or XInput acceptance.
The subprocess fixtures verify real pipe framing, idle and partial-line
deadlines, EOF and oversize handling with the offline helper.

An initial subprocess run failed 2/7: Windows redirected stdin did not honor
`ReadAsync` cancellation. The retained failed JSON is evidence. The final
helper places its blocking reader on a background task and applies a finite
foreground `WaitAsync` deadline; it never starts another reader after timeout.
Both configurations subsequently pass 7/7.

## Adapter contract and IPC

`IVirtualXboxController` exposes `Create`, `SubmitState`, `SetRumbleCallback`,
`Disconnect` and `Dispose`. Native and managed adapters have the same state
and rumble ranges; no WinUSB type enters this interface. The SDK adapter uses
only public `HMContext`, `HMController`, `HMGamepadState`,
`HMGamepadStateHelpers.StandardAxes` and output event APIs. No private
shared-memory ABI is reproduced.

Launch the default helper explicitly, using its framework-dependent executable
or `dotnet ChatpadVirtualXbox.dll`:

```text
ChatpadVirtualXbox.exe helper --backend unavailable --duration-ms 30000 --idle-ms 1000
ChatpadVirtualXbox.exe helper --backend mock --duration-ms 30000 --idle-ms 1000
```

The native parent writes UTF-8 LF-terminated lines, at most 4096 bytes each:

```json
{"id":1,"op":"create"}
{"id":2,"op":"submit","buttons":4096,"leftTrigger":255,"rightTrigger":0,"lx":0,"ly":0,"rx":0,"ry":0}
{"id":3,"op":"disconnect"}
{"id":4,"op":"quit"}
```

`id` is a nonnegative int32. Buttons are uint16, triggers uint8 and sticks
int16; all seven state fields are mandatory. Duplicate/unknown fields,
non-integers, missing fields and out-of-range values are rejected.

Each request receives one stdout JSON acknowledgement:

```json
{"id":1,"ok":true,"operation":"create"}
{"id":1,"ok":false,"error":"backend_unavailable","detail":"..."}
{"event":"rumble","leftMotor":32896,"rightMotor":65535}
```

The last form is an asynchronous callback; the parent must accept it while
waiting for acknowledgements and serialize physical writes separately.
SDK diagnostics use stderr. EOF and `quit` disconnect. Unavailable is an
explicit error, never a successful virtual-device creation. An idle/request
deadline expires with `deadline_or_cancellation` and exit 4; arguments fail
with exit 2. Normal quit/EOF exits 0. At most 10,000 requests and 120 seconds
are accepted per process. Parent-side process/writes/reads must also have
finite deadlines and terminate a stuck dependency process. The managed
deadline cannot guarantee cancellation of an upstream synchronous lifecycle
call; a real SDK process still needs that parent watchdog.

## Prepared real backend: bounded dependency

After separately authorizing installation/toolchain changes, provide .NET 10
and a provenance-verified prebuilt external SDK:

```powershell
tools/ChatpadVirtualXbox/Build.ps1 -EnableHidMaestro -HidMaestroSdkPath <verified-sdk-dll>
```

This conditional source has not compiled in C2. Even in that build,
`--backend hidmaestro` refuses `create` before SDK context construction unless
`--allow-live-virtual` is explicitly supplied. That switch is a later runtime
gate, not authorization to execute it during C2.

Upstream `HMContext` construction schedules background resource extraction
and `EnsureGameInputService`; it is not a side-effect-free presence probe.
Upstream `CreateController` creates PnP nodes, modifies per-instance/GameInput
registry configuration and can automatically call `FullDeploy` when its
driver-store check fails. Our adapter never calls `InstallDriver`, refuses
missing drivers before `CreateController`, selects only `xbox-360-wired` and
refuses a USB/IP profile. The preceding check cannot eliminate a later SDK
installation race. C3 must audit/authorize those upstream effects and
independently verify installed packages before permitting creation; this
helper is not an installer-isolation guarantee. C2 never instantiated
`HMContext` or ran any of these paths.

State conversion retains XInput bit semantics and maps D-pad to the public
hat enum. Opposed D-pad directions become neutral. Pinned SDK conversion
inverts Y and quantizes normalized floats, so the adapter reverses Y and
uses upward rounding to preserve integer stick/trigger values through the
source-model XInput path. Guide is submitted via the public button mask;
ordinary documented `XInputGetState` does not expose Guide, so its live
acceptance remains a separate unresolved item.

Only the exact pinned upstream `test/Program.cs:873` rumble fixture
`source=XInput`, `reportId=0`, five bytes `00 00 lo hi 00` is accepted.
Motor bytes map to uint16 by multiplying by 257. Unknown formats go to
stderr; they never silently generate physical output. The upstream SDK
relays other raw XUSB IOCTL buffers too, and this fixture has not been
validated with a real game. Complete rumble remains UNTESTED in C3.

## Independent read-only observer

```text
ChatpadVirtualXbox.exe snapshot --slot 0
ChatpadVirtualXbox.exe observe --slot 1 --expect-file state.json --timeout-ms 1000 --poll-ms 10
```

`state.json` contains the seven numeric state fields in the submit example,
without `id`/`op`. The intended XInput slot is mandatory (0..3). The observer
calls documented `XInputGetState` only, records its return code and packet,
matches every state field exactly and fails with exit 3 on deadline/mismatch.
It never chooses the first connected slot and never calls `XInputSetState`.
Guide-positive expectations are rejected. Provide an outer watchdog for the
synchronous Windows API, as for other diagnostic subprocesses.

Matching a slot/state alone cannot identify its PnP origin. In C3 first prove
physical XInput disappears under WinUSB, census every slot before virtual
creation, correlate the intended virtual instance/slot, and submit a
distinct known state. An already connected physical controller or a neutral
state match is not virtual acceptance. Output explicitly sets
`identityProven=false`. A C2 read-only slot-0 snapshot succeeded on the
existing physical controller; it does not verify the real backend.
