# Project State

Updated 2026-10-05 for startup zero-rumble recovery correction.

- Branch: `feature/chatpad-usermode-runner`; implementation/build commit: `2258de10c65052a12efff8acfa30f2773dc546ad`.
- Live evidence: the user-tested package logged controller polling before Chatpad activation, then `initial zero-rumble command failed win32=1460` while `unclean_previous_session=false`; it reconnected eight times before Ctrl+C. This disproved the polling-gap hypothesis.
- Source correction: clean starts skip the redundant startup zero-rumble transfer. An unclean prior-session marker still triggers one recovery attempt; failure stops startup and preserves the marker without retrying through reconnect. Graceful cleanup still sends neutral state. Live effect remains unverified.
- Offline verification: latest focused run passed packaged managed tests 504/504 (three runs), native CTest 3/3, setup checks (repository identity 5, package identity 8, baseline 5, PnP 4), readiness/privacy 9/9, publication receipt 5/5, repository safety PASS. Package inventory 214/214 files with exact manifest hashes.
- Prepared release: timestamp `20261005T040900Z`, package source commit above, archive SHA-256 `C03531153A5AF9E7407970DBBBA1AC88B9155C731294A1B42541BFF3C343CD07`; final publish and remote readback remain pending.
- Broker service remains reported Running after the user's successful RepairBroker operation. This source change does not change service bytes; no further elevated repair is expected.
- Safety: no live service, PnP, binding, registry, trust, device, reboot, elevated bridge, or global HIDMaestro cleanup by the agent; `legacy/` untouched.

## Next

Commit and push the release-identity continuity update, publish timestamp `20261005T040900Z`, and verify the published sidecars and completion receipt. Then provide the user the exact normal-user run command. Do not claim the recovery change fixed live rumble until the user returns the new runtime output.
