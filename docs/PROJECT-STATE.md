# Project State

Updated 2026-10-04 after the fixed package exposed a broker service exit during create.

- Branch: `feature/chatpad-usermode-runner`; current starting HEAD is `2daa6a4e3a23ba3e250600705f9a08323f84b4b0`. The user repaired and ran the locality-fix package.
- Live state: WinUSB opened and Chatpad activation stages 0–5 succeeded, then the runner received `broker_pipe_closed:109` during broker create. SCM event 7023 reports the service terminated with generic code 1 (`ERROR_INVALID_FUNCTION`); event 7031 scheduled automatic recovery. A read-only status query observed Stopped, and a later query observed Running after SCM recovery. The actual managed exception was not recorded in Event Log.
- Fix: `WindowsClientIdentity` now accepts Win32 229 as the defined local-pipe result, compares computer names when the API succeeds, and fails closed on all unrelated API errors. User SID, active-console session, first-frame ordering, pipe ACL, and remote-rejecting pipe mode remain enforced.
- Change in progress: `WindowsServiceHost` currently catches service exceptions but only writes to `Console.Error`, unavailable through SCM. A bounded, single-line failure record is being added under the protected install root so the next managed exception is observable without changing IPC authorization or cleanup policy.
- Prior package: `artifacts/task-8lc4l2/build-broker-local-pipe-229-3961374/package`, 214/214 members hash-verified; runner SHA-256 `FCAFD7A30EAA3BEBD0D49CBE74FC21C0E0989C3DDEDB3EA41E4F82FACFB268FA`, broker SHA-256 `330C8EADBAFDE5F90BBCA08476C5BF388150603DCA86F05EE519860481DB1329`. It predates the diagnostics source change.
- Verification: .NET 10 managed build succeeded with zero warnings/errors. Offline self-test: 155 passed, 1 failed because the pipe-squatter test cannot claim the fixed pipe while the installed service owns it. No service stop was attempted.
- Remaining acceptance: build/verify/push diagnostics package, user-run elevated `RepairBroker`, then normal-user create/XInput, controller and Chatpad input, rumble, cleanup, reconnect, and crash recovery. Hard-client-crash physical rumble remains an accepted limitation.
- Safety: no service lifecycle/configuration action, driver/PnP/registry/device mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup was performed by this agent. `legacy/` is untouched.
