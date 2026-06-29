# Project State

*Last updated: 2026-06-29T18:12+04:00*

## Current state

- **Branch:** `feature/mocked-activation-executor`.
- **Starting checkpoint:** `e1de1860e2f2ea21146e8de8aeec19892d2c9203`.
- **Expected task commit:** `feat: add mocked activation executor` (this
  implementation and continuity commit).
- **Initialization/status audit:** complete. The authoritative analysis remains
  `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`.
- **`0x90` conclusion:** its only legacy occurrence is a tentative comment on
  an unused internal structure. It is not proven as payload or a USB setup
  field.
- **Initialization-related `0x00` conclusion:** the executable activation path
  confirms `0x00` as the second payload byte in `09 00`; the `00` beside `90`
  is not proven wire data.
- **Activation-request builder:** implemented as a transport-independent,
  caller-owned value-copy API in `ChatpadActivationRequests.h/.c`. It exposes
  exactly six confirmed request descriptors in the legacy executable order.
- **Activation-sequence planner:** implemented as a transport-independent,
  caller-owned value-copy API in `ChatpadActivationSequence.h/.c`. It exposes
  exactly six steps, one-to-one with the request builder indexes, and obtains
  each request from the builder rather than duplicating request tuples.
- **Activation executor:** implemented as a portable, transport-independent
  callback contract in `ChatpadActivationExecutor.h/.c`. It consumes the
  activation-sequence planner, emits each planned request through `OnRequest`,
  emits nonzero post-request delay metadata through `OnDelayMetadata`, and
  records only planner/callback outcomes in `ChatpadActivationExecutionSummary`.
- **Executor operation order:** for each step, retrieve planner step, emit
  request callback, emit delay metadata callback when delay-after metadata is
  nonzero, then advance only if the emitted operation is accepted. Current
  planner metadata yields request 0, delay 0 12 ms, request 1, delay 1 12 ms,
  request 2, delay 2 12 ms, request 3, delay 3 12 ms, request 4, delay 4
  12 ms, request 5, delay 5 12 ms.
- **Activation sequence timing metadata:** every step has
  `DelayBeforeMilliseconds = 0` and `DelayAfterMilliseconds = 12`. The executor
  emits only the nonzero after-delay metadata. The value is declarative only:
  no active wait, timer, timeout, retry, response deadline, acknowledgement, or
  readiness condition is represented.
- **Activation request facts:** `09 00` appears only as the confirmed outbound
  payload for request/step index 4. `90 00` is absent from every request
  descriptor, sequence step, fixture, executor record, payload, and test.
- **Sequence/response boundary:** the request builder, planner, and executor
  contain no response bytes, acknowledgement schema, readiness state, retry
  policy, timeout/deadline, I/O, USB/HID/IOCTL access, hardware access, sleep,
  timer, allocation, transport status, or driver integration.
- **Portable parser:** unchanged Phase 1 five-byte raw keyboard parser.
- **Portable state machine:** unchanged caller-owned, allocation-free
  last-classification state and deterministic transition output.
- **Tests:** 610/610 pass directly and in integrated Debug/Release x64 builds.
  The total is 85 parser assertions, 89 state-machine assertions, 126
  activation-request assertions, 143 activation-sequence assertions, and 167
  activation-executor assertions.
- **User-mode artifacts:**
  - Direct test executable:
    `artifacts/bin/x64/Debug/ChatpadProtocolParser/ChatpadProtocolParserTests.exe`
    SHA-256 `D6E533D6A59BFE312E8EDF9B9A993D60E59CCA7B810710A62CB71A02AEF7A435`
  - Debug library:
    `artifacts/bin/x64/Debug/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
    `68984F9F9C0ABC6107AD01E4387E7DAAA0E2418A089AB31F26FC743995502C64`
  - Debug tests:
    `artifacts/bin/x64/Debug/ChatpadProtocolTests/ChatpadProtocolTests.exe`
    SHA-256 `2700503C6D96053E152C1EFA36FD4F16C3A8CBE80EEFBDD4BFFB1E1DB7605AF6`
  - Release library:
    `artifacts/bin/x64/Release/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
    `15336EE73D68F9AE4CD40C245393B6CE7AECCBD2C7AC2193C044DCB53CA62F87`
  - Release tests:
    `artifacts/bin/x64/Release/ChatpadProtocolTests/ChatpadProtocolTests.exe`
    SHA-256 `1F1D704A478F6353C27B472083012C027A89C8A03B5F4881941BC9ADF4D49C42`
- **WDK compatibility:** Debug and Release x64 static libraries compile the
  activation executor, activation-sequence planner, activation-request builder,
  parser, and state machine with exit 0; only `.lib` outputs are produced.
  - Debug:
    `artifacts/bin/x64/Debug/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`
    SHA-256 `D5A7D38056C9FEACCE884CA9368695A05B106EE0499113CE9230BD46C0D9820C`
  - Release:
    `artifacts/bin/x64/Release/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`
    SHA-256 `5353CE201671210CFBF0DA5E41CBF9C358D827E907BDDFFB86D57920AE789DA2`
- **Driver regression:** Debug and Release exit 0, remain NotSigned, and run no
  signing operation.
  - Debug:
    `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys` SHA-256
    `7daea18602f33f7e00d8525ca12ea3d9541ed9648de2e97707dff3092a679c11`
  - Release:
    `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys` SHA-256
    `8fb2e1a7832c07081960c551334f93dcd89a21e4a8ddcd0e093ce8d11d2cbb08`
- **Driver isolation:** `ChatpadFilter.vcxproj` has no protocol project
  reference and no protocol source, including no activation-request,
  activation-sequence, or activation-executor source. Diagnostic linker inputs
  contain driver objects and WDK/KMDF libraries only; neither
  `ChatpadProtocol.lib` nor `ChatpadProtocolKernelCompileCheck.lib` is linked
  into `ChatpadFilter`.
- **Toolchain:** Visual Studio 2022 17.14.35; MSVC 14.44.35207; SDK/WDK
  10.0.26100.0; latest installed KMDF 1.35; driver target/link version 1.15.
- **Unresolved blockers:** Response bytes, `f0` packet meaning, the three
  mystery setup requests, periodic request semantics, objective ready
  conditions, and connected-device inventory remain unresolved.
- **Safety:** PASS. `legacy/` unchanged, prohibited commit absent, generated
  files ignored beneath `artifacts/`, and no runtime, hardware, USB, HID,
  IOCTL, installation, signing, packaging, deployment, loading, capture,
  external-skill, or driver-runtime action occurred.
