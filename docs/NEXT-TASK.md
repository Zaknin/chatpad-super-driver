# Next Task

## Close C3 prerequisites before any live WinUSB experiment

### Exact state and starting point

Branch `feature/chatpad-winusb-bridge-poc`; start from the coherent C2 commit `feat: prepare bounded WinUSB bridge experiment`, direct child of `672869d8e6138b80c1bcbe24cf2c22680066efcf`. Obtain exact SHA with `git log -1 --format=%H` and confirm pushed feature branch and canonical result-manifest agree. Preserve `research/chatpad-usermode-transport` and known fallback branches.

C2 verdict PARTIAL. Native POC/protocol/SendInput/helper IPC and mock backend build; unsigned WinUSB package and guarded binding-only selector prepared. Current physical controller remains healthy xusb22 with retained extension/filters. No live mutation occurred. Offline native 578, managed 85+7, binding 38, publisher 8, existing protocol 904/control 15 checks pass; actual SDK compile blocked NETSDK1045 and entire physical bridge untested.

### Next recommended objective

Resolve an exact reviewed extension exclusion **and complete restoration path** without assuming property clearing prevents PnP extension reapplication. Current binding tool cannot switch this installed filtered baseline or repair filter drift; no global cleanup/package removal is implicitly authorized. Review package signing/trust policy, real .NET10/external pinned SDK compilation, and upstream runtime side effects. Produce inspectable prerequisites and rollback before asking for live authorization. Do not reopen C1 architecture absent contradicting implementation evidence.

### Preconditions and restrictions

Read AGENTS, PROJECT-STATE, DECISIONS, latest WORKLOG; C2 plan, POC README, binding/backend docs and C3 procedure. Reconcile clean/synchronized Git, actual PnP/service/image state and private immutable baseline hashes. Inspect canonical manifest/receipt and all SHA sidecars. No live binding/install/package removal/restart/reboot/input injection/security/trust/power mutation without a later explicit exact task. Never edit legacy or gratuitously change the working driver. Generated/private outputs remain under ignored artifacts; preserve all C1/C2 failure evidence.

### Acceptance criteria

1. A narrowly scoped exclusion/restoration design and executor can restore the exact extension/filter/base binding after clean WinUSB, independently of a working POC; tests cannot claim physical rollback.
2. Exact WinUSB INF/catalog trust requirement and authorized future signer/install policy are recorded; no "driverless" claim.
3. Public HIDMaestro SDK source compiles against verified pinned external dependency, with its constructor/create/install side effects bounded and reviewed; no implicit installation during tests/startup.
4. Ambiguous Win3231 stops strict activation unless authoritative USBSTALL evidence becomes available; no guessed bytes or broad failure acceptance.
5. Only then propose the finite sixteen-stage C3 sequence, with independently identified virtual slot, real packets/keyboard/rumble, unplug/Ctrl+C and exact restoration acceptance. Actual C3/normal-boot functionality remains untested until that later authorized execution.

First inspect `git status --short --branch`, `git log -3 --oneline`, `tools/ChatpadBinding.ps1 -Status`, `tools/ChatpadBinding/ChatpadBinding.psm1`, `ExactDevice.cs`, `tools/ChatpadWinUsbPoc/`, `tools/ChatpadVirtualXbox/HidMaestroBackend.cs` and `artifacts/task-8lc2/binding/baseline-verified/`. No new chat/task is created by C2.
