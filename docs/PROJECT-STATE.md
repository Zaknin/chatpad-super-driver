# Project State

Updated 2026-10-04 after isolating the broker create-failure cleanup bug.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD `a5a082f3081d08c16e6e728005c8f784ce1fd93`; create-failure cleanup correction is implemented locally and its package is pending.
- Live state: locality-fix diagnostic package passed WinUSB and Chatpad activation, then got `broker_pipe_closed:109`; its protected service log captured `BackendException: Create first.` at `BrokerSession.ReleaseBackendAsync` → `StopAsync` → `BrokerPipeServer.RunAsync`. SCM observed service exit and automatic recovery.
- Root cause: on backend create failure, `BrokerSession.ReleaseBackendAsync` unconditionally submitted neutral state to a `GuardedBackend` whose controller had never been created. That cleanup call threw `Create first.`; `CreateAsync` left the backend assigned, so `StopAsync` retried the same invalid state submission and terminated the service.
- Fix in progress: session cleanup submits neutral state only after `Create()` returned successfully. Failed create still clears callbacks, disconnects, disposes, and preserves the original create error. The protected, bounded service failure log remains for future faults.
- Verification: regression was red before the fix (155 passed, 2 failed including the new test); after fix, .NET 10 build succeeded with zero warnings/errors and offline suite reported 156 passed, 1 environment-limited pipe-squatter failure because the installed service owns the fixed pipe.
- Remaining acceptance: build/push the correction package, user-run elevated `RepairBroker`, then normal-user broker create/XInput, controller and Chatpad input, rumble, cleanup, reconnect, and crash recovery. If the service fails again, read `ChatpadBrokerService.log` under the protected install root. Hard-client-crash physical rumble remains an accepted limitation.
- Safety: no service lifecycle/configuration action, driver/PnP/registry/device mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup was performed by this agent. `legacy/` is untouched.
