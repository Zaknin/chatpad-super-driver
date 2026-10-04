# Project State

Updated 2026-10-04 for TASK 8L-C4L2 `InstallBroker` argv correction.

- Branch: `feature/chatpad-usermode-runner`. Setup fix commit `2315358c06243629892e33cfe2b294483a5b7a3a` is pushed. The final continuity commit will change docs only; readiness must be regenerated against that final HEAD before retry.
- The prior user-run elevated `InstallBroker` attempt failed at `sc.exe create` with exit 1639. Read-only checks now show the service absent: `sc.exe query` returned 1060, CIM found no service, and `HKLM\SYSTEM\CurrentControlSet\Services\ChatpadHidMaestroBroker` is absent. Package files/auth configuration may have been copied before the failure; the retry's normal install path revalidates/overwrites members.
- Root cause fixed: `sc.exe` options and values are separate argv elements for create/config/failure; `failureflag` already used valid separate tokens and is now covered by the same exact-array regression. `Invoke-ChatpadBrokerSc` continues to splat the argument array directly.
- Fresh local self-contained win-x64 package: `artifacts/task-8lc4l2/build-installbroker-argv-2315358/package` (214 members). Setup tests pass including native argv shapes 4/4; package/readiness identities match build commit `2315358c06243629892e33cfe2b294483a5b7a3a`. Exact setup-script SHA-256: `9227780FC664CF9A58B0369BB956E356CE23B20FB0E1B0FF07A9773F6818EA96`.
- The earlier canonical archive at `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261004T171319Z\` predates this fix and must not be used for retry. The fresh package/readiness is local and is not republished by this corrective task.
- Live service installation/lifecycle and normal-user broker → XInput, Chatpad, rumble callback, reconnect, graceful cleanup and crash recovery remain untested. The accepted hard-client-crash physical-rumble limitation remains.
- Safety: no service installation/configuration command, driver/PnP/registry/device mutation, trust/security change, reboot, or elevated bridge run was performed by this task. `legacy/` was untouched.
