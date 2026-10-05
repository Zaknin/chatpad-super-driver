# TASK 8L-C4L2 — Publish and retry clean-start recovery correction

## Current state

- Required branch: `feature/chatpad-usermode-runner`; starting HEAD `344644548bec4f8ba4361b9dbe6ee0bc42c1900a`.
- The user's latest run confirmed `controller input polling started before Chatpad activation` but still timed out the initial zero-rumble write. It reported `unclean_previous_session=false` and later reconnected eight times before Ctrl+C. This disproves the polling-gap hypothesis for this failure.
- Source now sends startup zero-rumble only when the previous process marker exists. Clean startup skips the redundant output transfer. Failed unclean recovery stops once and preserves the marker; it does not enter a repeated reconnect/write loop. Graceful cleanup still neutralizes motors.
- Focused verification so far: `ChatpadRunnerLifecycleTests` 17/17 and native CTest 3/3 (`controller-input-pump`, `broker-client`, `runner-lifecycle`). Build/package/publication checks remain pending.
- User already repaired the broker successfully. Only normal-user bridge bytes change; no additional elevated service repair is expected.

## Next steps

1. Complete focused setup/readiness/publication/safety checks, inspect the diff, commit, and push only `feature/chatpad-usermode-runner`.
2. Build a fresh package from exact pushed HEAD, verify the helper suite and all package member hashes, then atomically publish at a new UTC timestamp.
3. Give the user the exact ordinary PowerShell command for the fresh package and request the full output after stopping.
4. Confirm clean-start recovery is skipped, virtual controller creation succeeds, and the runner stays active. Later, separately verify unclean-session recovery and its single-attempt failure behavior.

## Safety and acceptance

- Do not perform service lifecycle changes, driver binding, PnP/registry mutation, trust changes, reboot, elevated bridge execution, or HIDMaestro global cleanup.
- Do not retry a failed unclean-session zero-rumble command automatically. Preserve the marker so recovery remains visible on a later launch.
- Do not claim XInput or physical rumble pass until separately observed live.
- Inspect first: `Runner.cpp`, `RunnerLifecycle.{h,cpp}`, `runner-lifecycle-tests.cpp`, and package/publisher verification records.
