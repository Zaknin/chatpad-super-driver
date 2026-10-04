# Project State

Updated 2026-10-04 after confirming the latest live run used the previous broker package.

- Branch: `feature/chatpad-usermode-runner`; fix commit `3961374159a2b095cd0810a1e16c5bb5334bfd5d` is built; continuity updates are being committed and pushed to the same branch.
- Live state: the user repaired and ran `build-broker-read-before-impersonation-f5d5885`, which predates the locality fix, and again received `broker_peer_unauthorized`. The package containing the fix has not yet been confirmed installed or run.
- Fix: `WindowsClientIdentity` now accepts Win32 229 as the defined local-pipe result, compares computer names when the API succeeds, and fails closed on all unrelated API errors. User SID, active-console session, first-frame ordering, pipe ACL, and remote-rejecting pipe mode remain enforced.
- Package: `artifacts/task-8lc4l2/build-broker-local-pipe-229-3961374/package`, built from commit `3961374159a2b095cd0810a1e16c5bb5334bfd5d`. Exact readback passed 214/214 files. `ChatpadBridge.exe` SHA-256: `FCAFD7A30EAA3BEBD0D49CBE74FC21C0E0989C3DDEDB3EA41E4F82FACFB268FA`; `ChatpadVirtualXbox.exe` SHA-256: `330C8EADBAFDE5F90BBCA08476C5BF388150603DCA86F05EE519860481DB1329`.
- Verification: C4 setup/package/readiness checks passed; focused native CTest `broker-client|runner-lifecycle` passed 2/2. Managed self-test reported 153 passed and one environment-limited failure because pipe-squatter test cannot bind while the installed service owns the fixed pipe. No service stop was attempted.
- Remaining acceptance: user-run elevated `RepairBroker` and normal-user run using `build-broker-local-pipe-229-3961374`, then broker create/XInput, controller and Chatpad input, rumble, cleanup, reconnect, and crash recovery. Hard-client-crash physical rumble remains an accepted limitation.
- Safety: no service lifecycle/configuration action, driver/PnP/registry/device mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup was performed for this fix. `legacy/` is untouched.
