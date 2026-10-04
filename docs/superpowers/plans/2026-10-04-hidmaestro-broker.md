# TASK 8L-C4L2 HIDMaestro Broker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Implement each task in order with test-first steps and commit after its focused verification.

**Goal:** Keep `ChatpadBridge.exe` at normal-user integrity while an installed LocalSystem service owns only HIDMaestro virtual Xbox creation, state submission, and destruction.

**Architecture:** Extend `ChatpadVirtualXbox.exe` with a protected-path Windows Service host and a single-owner, versioned named-pipe server. Keep the native bridge responsible for physical USB and send controller states on a bounded, one-way latest-state stream; reserve request/response RPCs for `ping`, `create`, and `destroy`.

**Tech Stack:** Existing C++17/Win32 bridge, C#/.NET 10 self-contained service, pinned HIDMaestro v1.10.1, PowerShell setup/package scripts, CMake/CTest, repository atomic publisher.

**Spec:** `docs/superpowers/specs/2026-10-04-hidmaestro-broker-design.md`, updated with the three user-approved clarifications before this plan was written.

## Global Constraints

- Branch `feature/chatpad-usermode-runner`; begin from the branch HEAD after this plan is approved.
- `ChatpadBridge.exe` remains normal-user and retains WinUSB, Chatpad, parsing, keyboard injection, controller state source, and physical rumble output.
- The pipe DACL grants only `SYSTEM` and the specifically authorized installed user SID. Accept a client only when its token SID matches and its session is the active local console session; reject other users, RDP sessions, anonymous tokens, and remote pipe clients.
- `submit-state` is one-way and sequenced. Client and service each use a bounded latest-value queue; physical input never waits for a per-frame response and stale queued states are coalesced. `ping`, `create`, and `destroy` remain correlated bounded RPCs.
- Service executable, self-contained .NET runtime, SDK dependencies, and service configuration use absolute paths under protected `%ProgramFiles%\ChatpadBridge`. Service startup must not resolve files from cwd or user-writable directories. IPC accepts no paths.
- Never call HIDMaestro `InstallDriver` or global `RemoveAllVirtualControllers`; preserve existing exact metadata and present-index guards. Fail closed on ambiguous orphan/device identity.
- Offline build, tests, package hash/identity checks, and publication precede any live step. Do not install/start/repair/stop/uninstall the service, mutate drivers/PnP/registry/security/trust, reboot, or run `ChatpadBridge.exe` elevated. The user performs the elevated setup step after offline PASS.
- Preserve the accepted limitation: after hard bridge-process crash the broker cannot stop physical rumble; next bridge launch owns existing abandoned-key and zero-rumble recovery.
- Do not modify `legacy/`; generated files remain under ignored `artifacts/`.

## Review Focus

- Wrong user SID, non-console session, or RDP peer tries to claim the controller lease — reject before any HIDMaestro call.
- A user-writable cwd/config/dependency or a path sent over IPC attempts to influence the LocalSystem process — resolve only validated absolute install-root members; reject reparse/path escape.
- The service is slower than physical reports — bounded latest-state queues coalesce without blocking input or accumulating stale frames.
- Client disconnect, malformed stream, or timeout races with rumble callback/control RPC — serialize output and teardown; neutralize/destroy once and report cleanup failure.
- Service crash leaves stale HIDMaestro state or another present index-zero controller — retain guard, never global-sweep, fail closed, and prove restart behavior separately.

### Task 1: Define IPC/security policy and protocol regressions

**Files:**
- Create: `tools/ChatpadVirtualXbox/BrokerProtocol.cs`
- Create: `tools/ChatpadVirtualXbox/BrokerPeerAuthorization.cs`
- Create: `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`
- Modify: `tools/ChatpadVirtualXbox/OfflineTests.cs`

**Interfaces:**
- `BrokerProtocol` parses exact v1 control frames, sequenced `submit-state` frames, control responses, `rumble` events, and asynchronous session faults; frame limit remains 4096 UTF-8 bytes.
- `BrokerPeerAuthorization` accepts an injected peer-token/session snapshot and the installed authorized SID; it returns allow only for that SID in the active local console session. `WindowsClientIdentity` is the only token/WTS native API adapter.

- [ ] Add failing tests for exact operation/property sets, v1 mismatch, duplicate/unknown JSON fields, ranges, sequence monotonicity, oversized frames, wrong SID, stale/non-console session, RDP protocol type, and anonymous/remote peers.
- [ ] Run the managed offline self-test and confirm the new assertions fail for the missing contract/policy.
- [ ] Implement protocol and injectable authorization policy; keep native token acquisition behind one Windows adapter.
- [ ] Re-run focused managed self-test; require exact case counts and zero failures; commit.

### Task 2: Implement LocalSystem service host and broker session

**Files:**
- Create: `tools/ChatpadVirtualXbox/WindowsServiceHost.cs`
- Create: `tools/ChatpadVirtualXbox/BrokerPipeServer.cs`
- Create: `tools/ChatpadVirtualXbox/BrokerSession.cs`
- Modify: `tools/ChatpadVirtualXbox/Program.cs`
- Modify: `tools/ChatpadVirtualXbox/HidMaestroBackend.cs`
- Modify: `tools/ChatpadVirtualXbox/OfflineTests.cs`

**Interfaces:**
- Add `Program service` mode that enters SCM dispatch; retain `self-test` without service installation or SDK context construction.
- Implement SCM hosting using `StartServiceCtrlDispatcherW`, `RegisterServiceCtrlHandlerExW`, and `SetServiceStatus` P/Invoke; add no service-host NuGet dependency.
- Broker server accepts local duplex clients only with DACL `SYSTEM + authorized SID`, rejects remote clients, and validates the active console session before granting the one controller lease.
- Control ops call the existing guarded HIDMaestro backend. A capacity-one/drop-oldest state channel and a single backend worker apply only the newest valid state. All response, rumble, and fault writes share one bounded writer.

- [ ] Add mock-backend tests for ping without context, one lease, create/duplicate create, streamed latest-state behavior, control correlation, rumble callbacks, destroy idempotence, and destroy/neutral/dispose on EOF, malformed frame, exception, and service stop.
- [ ] Add failing tests for concurrent owner, unauthorized identities, sequence regression, queue backlog, callback/write races, and teardown timeout reporting; run to observe failures.
- [ ] Implement SCM start/stop reporting and the secured pipe/session lifecycle. No user-supplied path/profile/command reaches the service backend.
- [ ] Re-run managed offline tests; require connection loss to clear only the owned virtual controller and never call global HIDMaestro cleanup; commit.

### Task 3: Replace child-helper RPC with the native broker client and state stream

**Files:**
- Create: `tools/ChatpadWinUsbPoc/VirtualBrokerController.h`
- Create: `tools/ChatpadWinUsbPoc/VirtualBrokerController.cpp`
- Modify: `tools/ChatpadWinUsbPoc/Runner.cpp`
- Modify: `tools/ChatpadWinUsbPoc/CMakeLists.txt`
- Modify: `tools/ChatpadWinUsbPoc/runner-lifecycle-tests.cpp`
- Create or replace: `tools/ChatpadWinUsbPoc/broker-client-tests.cpp`
- Retire production use of: `tools/ChatpadWinUsbPoc/VirtualHelper.cpp` and `.h`

**Interfaces:**
- Native controller keeps the `IVirtualXboxController` shape. `Create`/`Disconnect` use correlated bounded RPCs; `SubmitState` publishes a monotonic sequence into a capacity-one latest-state slot and returns without waiting for a service acknowledgement.
- Dedicated overlapped pipe writer streams/coalesces states; one reader dispatches control replies, rumble callbacks, and asynchronous faults. `ping` confirms service readiness before `create`.

- [ ] Add failing client tests proving no per-state response is required, submit does not wait on an RPC, newest state wins under a blocked writer, sequence/order is preserved, and control/rumble frames cannot corrupt each other.
- [ ] Add runner lifecycle regressions for physical input-loop independence, repeated create/destroy on reconnect, pipe EOF, service fault, and cleanup flags; verify keyboard and physical rumble cleanup remain in the client.
- [ ] Implement named-pipe open/retry and stream framing; remove `CreateProcess` helper launch from runtime and keep the runner normal-user.
- [ ] Build native targets and run focused CTest cases `broker-client` and `runner-lifecycle`; run existing `helper` parser/lifecycle coverage only if retained and renamed explicitly; commit.

### Task 4: Add protected service setup, package identity, and self-contained deployment

**Files:**
- Modify: `tools/ChatpadSetup.ps1`
- Modify: `tools/Build-ChatpadBridge.ps1`
- Modify: `tools/ChatpadC4Package.psm1`
- Modify: `tools/New-ChatpadC4Readiness.ps1`
- Modify: `tools/Test-ChatpadC4Setup.ps1`
- Modify: `tools/Test-ChatpadReadinessArtifacts.ps1`
- Modify: `tools/Test-ChatpadPackageContent.ps1`
- Modify: `tools/ChatpadVirtualXbox/ChatpadVirtualXbox.csproj`

- [ ] Add setup contract tests first for `InstallBroker`, `RepairBroker`, `UninstallBroker`, and `Status`, including only the named service, fixed LocalSystem/automatic/recovery configuration, current elevated SID matching the active local console, and no physical binding operations.
- [ ] Add package regressions for stale/altered members, missing runtime files, absolute quoted service image path, cwd hijack, install-root escape/reparse point, and config/dependency paths outside protected Program Files.
- [ ] Publish the service self-contained so its apphost and managed/native runtime dependencies are packaged beside it. Extend readiness to hash the exact complete runtime member set; install/repair independently read back every installed member hash. Write `BrokerAuthorization.json` with the approved SID under the protected install root and store its expected hash in the service's protected Parameters record; service startup verifies both.
- [ ] Implement elevated service modes. `InstallBroker` copies and verifies members, creates/starts only the named service; `RepairBroker` drains/stops and verifies/replaces the same members; `UninstallBroker` stops/verifies cleanup and removes only the service registration. `Status` reports service identity/state without mutation.
- [ ] Run focused C4 setup/readiness tests and managed self-test; require all package hashes/lengths and exact member set to pass; commit. Do not execute service setup in this task.

### Task 5: Offline release verification and atomic C4L2 publication

**Files:**
- Create: `tools/Publish-ChatpadC4L2.ps1` (reuse `tools/Publish-ChatpadArtifact.psm1`)
- Modify only as required: `tools/Build-ChatpadBridge.ps1`, `tools/ChatpadReadinessArtifacts.psm1`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, `docs/WORKLOG.md`, `docs/NEXT-TASK.md`

- [ ] Build a fresh Release package under ignored `artifacts/task-8lc4l2/` from the committed current branch; run focused managed tests, focused native CTest, C4 setup/readiness tests, and the existing applicable repository safety checks.
- [ ] Independently verify branch/commit/package identity, exact file set, readiness identity, and each packaged/installed-runtime hash; verify service runtime/config resolution is rooted only at absolute protected install paths.
- [ ] Produce offline evidence and an explicit `PARTIAL` runtime result while live setup/qualification remains unrun. Create deterministic archive and SHA-256 inventory.
- [ ] Publish package, evidence, result manifest, and completion sidecars with the existing atomic publisher under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\`; independently read back source/partial/final hashes and archive hash.
- [ ] Update continuity docs with exact offline test totals, canonical path, archive hash, and the remaining live gate; inspect diff/status and commit/push only `feature/chatpad-usermode-runner`.

### Separate live gate after offline PASS

Do not run this gate automatically. Give the user the exact elevated command for `ChatpadSetup.ps1 -Mode InstallBroker` and wait for its output. After successful setup, qualify with a non-elevated `ChatpadBridge.exe run`: active authorized local SID/session, WinUSB → bridge → broker → XInput state, Chatpad typing, physical rumble callback, unplug/reconnect, graceful cleanup, bridge crash then next-launch recovery, and service crash/restart without claiming orphans are gone unless read-only XInput/devnode evidence proves it. User performs the elevated setup step; no driver binding changes or reboot are included.
