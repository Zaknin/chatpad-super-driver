# Project State

Updated 2026-10-05 after publishing the startup zero-rumble recovery correction.

- Branch: `feature/chatpad-usermode-runner`; source/package build commit `2258de10c65052a12efff8acfa30f2773dc546ad`; published release identity commit `97095be21c420f55a26a7319b8a42323fd6fb6d4`.
- Live evidence from the prior release: polling began before Chatpad activation, but startup zero-rumble timed out (Win32 1460) with `unclean_previous_session=false`, followed by eight reconnects before Ctrl+C. This disproved the polling-gap diagnosis.
- Source correction: clean starts skip redundant startup zero-rumble. Unclean-session recovery remains a single attempt; failure stops startup and preserves the marker. Graceful cleanup still sends neutral state. This change has not yet been exercised live.
- Offline verification: packaged managed tests 504/504; focused native CTest 3/3; setup tests repository identity 5, package identity 8, baseline 5, PnP 4; readiness/privacy 9/9; publication receipt 5/5; repository safety PASS. All 214 package members matched manifest size/SHA-256.
- Published release: `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T040900Z`; archive SHA-256 `C03531153A5AF9E7407970DBBBA1AC88B9155C731294A1B42541BFF3C343CD07`; publication receipt sidecar SHA-256 `B3D83689CC638D30608BED6A9D382798E9A10FFF3920F28BEE3FA8F1ABB97A3E`. Independent readback verified six payload sidecars, exact release identity, and no `.part` files.
- User previously reported RepairBroker PASS. Only bridge bytes changed; no new elevated repair is expected.
- Safety: no live service, PnP, binding, registry, trust, device, reboot, elevated bridge, or global HIDMaestro cleanup by the agent; `legacy/` untouched.

## Next

Ask the user to run the published bridge from ordinary PowerShell and return the full output after Ctrl+C. Verify whether clean startup now reaches broker/controller operation. Keep live XInput and rumble status unqualified until observed; separately qualify unclean-session recovery later.
