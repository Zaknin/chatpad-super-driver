# Whole-device WinUSB transition and recovery

C2R1 prepares an exact future experiment. No live binding, Driver Store staging/removal or filter change was executed. Current target presence and runtime prerequisites come from read-only preflight, not the historical healthy C2 baseline.

The physical model is exactly USB\\VID_045E&PID_028E; no MI_02 can bind independently. The INF uses Microsoft's inbox WinUSB service and GUID {B6A5D05E-7E18-4DF1-8E47-12F072DE2C36}. It installs no custom SYS or coinstaller. See [signing conclusion](CHATPAD-WINUSB-TRUST.md) for package trust versus kernel-image policy.

## Read-only preparation

    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -VerifyRestorable
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PlanWinUsbTransition
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PlanRestoreXbox
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -PreflightC3 -JsonPath artifacts/task-8lc2r1/preflight-c3.json
    pwsh -NoProfile -File tools/Invoke-ChatpadC3.ps1

The transition plan blocks while the target is absent. VerifyRestorable separately verifies source hashes and Microsoft INF identity; it does not prove physical rollback.

ExtensionAllowlist.json records exact INF/SYS/CAT identities for versions 1.0.0 through 1.0.14. OEM numbers are rediscovered. ExtensionId, provider, hardware target, original INF name, version and exact bytes distinguish known from unknown packages. Candidate presence alone never proves selection. Selection stays unknown without target-associated Installed evidence.

An Extension INF can apply independently of the selected function INF and register instance LowerFilters. Selecting WinUSB alone therefore does not exclude ChatpadFilter. The future plan removes every captured known matching Extension package by exact OEM name, verifies disappearance, then removes only known ChatpadFilter/vhf instance LowerFilters from the unique captured target. Unknown packages, other filters, class filters, multiple targets and drift stop the plan. No Microsoft package removal, wildcard deletion or forced reboot occurs.

## Saved recovery

Before mutation, schema2 capture copies and hashes Microsoft recovery files and optional extension sources into coherent package folders under artifacts/. Cloned readiness records reference these copies; recovery does not rely on unchanged original source paths. Instance/container identifiers and raw baselines remain private.

Restoration does not open WinUSB or start the backend. It identifies the same captured physical container, permitting an instance-path change after reconnect, excludes captured matching extensions, clears only known instance filters, selects the exact Microsoft INF/provider/version/section with SetupAPI, verifies problem0/xusb22 without custom filters, then removes only the experiment INF identified by exact hash and GUID. Absence or ambiguity stops recovery; another connected device is never substituted.

    # Future recovery only, after human-started C3:
    pwsh -NoProfile -File tools/ChatpadBinding.ps1 -RestoreXbox -Execute -BaselinePath artifacts/.../private-baseline/baseline.json

Execution requires elevation and a complete schema2 baseline. No authorization token is required. Reboot requirements fail rather than initiating a restart.

Normal-Windows default restoration is Microsoft Xbox only. The retained development-signed Chatpad custom kernel driver has no proved ordinary-mode load qualification. RestoreExtension requires independent normal-mode qualification and exact attachment verification after a healthy base. Source preservation does not authorize reinstalling it.

Offline recovery tests verify source copies and failure contracts. No actual binding, recovery, reconnect, keyboard, virtual controller or motor acceptance occurred. The missing HIDMaestro runtime and absent physical target keep C3 BLOCKED.