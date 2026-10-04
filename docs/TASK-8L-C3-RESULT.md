# TASK 8L-C3 result

2026-10-04: **PASS for the revised core functional contract, including Microsoft-only recovery.** Branch feature/chatpad-winusb-bridge-poc, starting commit6c55e8999b5831a5ce42faabcc7075d84c420344. Final SHA and archive SHA are recorded by the canonical manifest/receipt after commit/push.

## Contract and live proof

The initial exact broken-baseline gate stopped before mutation. The user explicitly superseded it: prioritize functional proof, accept recoverable failures/replug/reboot, retain saved extension and recover clean Microsoft xusb22 without ChatpadFilter. Earlier gate files/log entry are historical, not the completed continuation's result.

Exact extension removal and device-filter clearing preceded prepared WinUSB bind. Windows reused the old OEM address and returned reboot/open-handle veto; restart was refused. User unplug/replug opened the interface without OS reboot. Actual WINUSB/prepared provider/version/WholeDevice.NT/problem0/no filters; live descriptors show IF0 IN81/OUT01 and IF2 IN84 plus remaining interfaces.

| Core path | Actual evidence |
| --- | --- |
| Controller | 1029 decoded real reports; A/B/X/Y, all D-pad, Start/Back, LB/RB, triggers0..255 and both sticks |
| Chatpad | Strict final activation and one-shot001B;524 valid five-byte reports in final session; initial activation capture also records Shift |
| Virtual XInput | Unique new slot0;109 observed states all exactly match captured physical states; zero unmatched; neutral buttons/triggers observed |
| Keyboard | Visible dedicated WinForms probe: letter, Shift, Space, Backspace, Enter and mapped Green/Orange behavior;439 events in final session; no held keys at end |
| Simultaneous | Controller/XInput and typing overlap in one session, both readers active |
| Physical rumble | Two bounded1.5s pulses total; user confirmed motors vibrated. Requested25000/12000, callback24929/11822, USB000800612E000000; zero stop0008000000000000 succeeded |
| Microsoft recovery | xusb22.inf10.0.26100.9278 / CC_Install / problem0, no extension/filters/experiment package; no reboot |

Successful session retained1863 events including all1029 controller and811 raw Chatpad events reported at close, below2048 cap. F0/status/startup packets remain rejected. Existing layout retained; Latin/Cyrillic text captured. Unsupported layout-dependent legends remain rejected, full legacy compatibility unclaimed. Stick drift means neutral buttons/triggers is not all-axis-zero physical neutral.

Post-core reconnect PASS: same hardware/container, activated Chatpad/controller reads and virtual mapping, eight connected XInput observations. Keyboard/rumble disabled for this check. Stop/nativeexit0/dispose/exact owned SWD phantom cleanup passed; independent no virtual nodes. Two physical replugs overall: initial bind completion and post-core check.

## Concrete failures and fixes

- Pending-reboot/open-handle veto and refused restart resolved by one manual replug. Original failed bind result retained.
- Early automatic recovery found former extension OEM name occupied by WinUSB. Exact hash recovery now skips that address until Microsoft binds, then removes exact experiment. Unknown drift still rejects; exclusion never accepts reuse. Four new cases.
- Binding recognition rejected actual WholeDevice.NT; added exact decorated section with existing provider/version/filter/stack/interface guards retained. One new case.
- Probe attempt1 Hidden/timed out before virtual creation. Visible attempt2 produced typing/rumble, but unsupported mapping wrongly fatal. LastOutputFailed now distinguishes rejected mapping/packet from failed SendInput/release. Three new native cases. Chatpad raw emitted before fatal; decoded controller and actual rumble bytes logged.
- Attempt2 wrapper checked present node before full drain and skipped complete raw-event saving after fatal. Evidence gap retained. Corrected attempt3 stopped/drained/disposed, removed exact owned phantom and independently proved absence. Operational probe/cleanup/reconnect orchestration stays ignored; reusable runner integration is follow-up.

Initial controller-only capture missed most user actions and proves startup/neutral only; later complete session supplies representative proof. Preactivation IF2 silence exit10 is an empty window, not PASS. Original command failures and focused red/green evidence retained; no failed result counts as success.

## Final verification and evidence

Clean Microsoft recovery completed without extension reinstall; exact saved extension and Microsoft recovery files remain private. Qualified HIDMaestro reused; final read-only availability/current trust verified. No bridge processes or present/phantom virtual controllers remain.

TESTSIGNING=false/HVCI=true, six certificate inventories unchanged. No BCD/security/trust changes, signing/new certificate, stock installer/HIDMaestro reinstall, stable driver/protocol/control/legacy edits. BCD byte equality UNVERIFIED_ACCESS_DENIED, errors retained. Headset/Guide/L3/R3, long-idle/crash/hot-unplug/latency/stress/benchmark unqualified.

Release native build PASS. Focused recovery28/28, binding39/39, native519/519. One final comprehensive after live2064/2064 plus retained package33/33/identity20/20 =2117/2117, zero failures, eight new tests. Earlier2109 run before revised authorization recorded; no broad suite during live iteration. Offline physical UNTESTED label is separate from live PASS.

Ignored local evidence artifacts/task-8lc3. Canonical: \\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C3\20261004T084034Z. Initial baseline/gate atomically published before mutation. Final deterministic task-8l-c3-live-winusb-bridge.zip, manifest/receipt bind actual committed/pushed SHA, member hashes/reproducible archive SHA and source/.part/final readbacks with sidecars last. Consult receipts for completion; this pre-publication document does not infer it. Private identities/full trust inventories/upstream/Microsoft binaries omitted.

No observed core blocker. Exact recommended next task: integrate proven probe/focus, pending-reboot/replug, drain/owned-phantom cleanup and Chatpad reconnect checks into reusable runner, then separately authorize lifecycle qualification. No next task automatically started.
Read-only source review found no correctness blocker. Medium follow-up: add decoded Chatpad HID/layer fields to the C3 JSON event schema; present JSON is raw, while the separate activation monitor records decoded HID/layer data. This does not change recorded core proof.
