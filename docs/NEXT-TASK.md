# Next Task

## Current state

- Current branch: `feature/offline-kmdf-production-linkage`.
- Expected checkpoint: pushed `build: link dormant request owner library`
  commit created from `033bd4fb4deff662ee9e3c2144d10decd27c8a03`.
- The authoritative production-linkage checkpoint is
  [Offline KMDF Production Linkage Checkpoint](OFFLINE-KMDF-PRODUCTION-LINKAGE.md).
- The tracked evidence manifest is
  [production-linkage-manifest.json](evidence/production-linkage-manifest.json).
- `ChatpadFilter.vcxproj` has exactly one native project reference to the
  existing `ChatpadKmdfRequestOwnerContext` static-library project. No
  production `.c` or `.h` file changed.
- No request-owner helper has executed. No production source embeds the owner,
  initializes it, invokes orchestration, creates a WDF request-owner object, or
  discovers a target.

## Recommended next objective

Perform an independent read-only audit of the project-linkage-only dormancy
checkpoint.

Do not embed the owner, initialize storage, invoke helpers, create WDF objects,
change callbacks, run the driver, or touch hardware.

## Required branch and starting commit

Start from the pushed `feature/offline-kmdf-production-linkage` checkpoint.
Verify the exact HEAD, parent, subject, upstream, and clean worktree/index
before any documentation correction. The expected parent is
`033bd4fb4deff662ee9e3c2144d10decd27c8a03` and the expected subject is
`build: link dormant request owner library`.

## Preconditions

1. Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, the latest `docs/WORKLOG.md` entry,
   `docs/OFFLINE-KMDF-PRODUCTION-LINKAGE.md`, and
   `docs/evidence/production-linkage-manifest.json`.
2. Inspect `ChatpadFilter.vcxproj`,
   `ChatpadKmdfRequestOwnerContext.vcxproj`, `ChatpadWin11.sln`, and current
   linker/include settings.
3. Confirm current production code still has no owner field, no context header
   include, no initializer call, no orchestration call, and no request-owner
   WDF object-management imports.

## Safety restrictions

- Keep the audit read-only unless documentation is demonstrably stale. If
  correction is needed, change only directly relevant Markdown or manifest
  text and record the correction in `docs/WORKLOG.md`.
- Do not modify `.c` or `.h` source for linkage-only dormancy.
- Do not invoke owner initialization, orchestration, rollback, target
  discovery, request formatting, request submission, completion, cancellation,
  signing, packaging, staging, installation, loading, device enumeration, or
  hardware interaction.
- Do not run source, driver, kernel, InfVerif, Inf2Cat, package, installation,
  or hardware tests unless the next task explicitly authorizes exact commands.

## Acceptance criteria

- The audit verifies the exact `ProjectReference` path, GUID, and metadata.
- The audit verifies the manifest matches actual tracked files and final
  evidence logs where practical.
- The audit verifies no production `.c` or `.h` file changed for the linkage
  checkpoint.
- The audit verifies final driver import/symbol evidence still shows no
  request-owner extraction and no new WDF object-management imports.
- The audit produces no runtime behavior change.
- Generated logs remain ignored beneath `artifacts\`.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
git diff --exit-code
git diff --cached --exit-code
Get-Content docs\OFFLINE-KMDF-PRODUCTION-LINKAGE.md
Get-Content docs\evidence\production-linkage-manifest.json
Get-Content src\driver\ChatpadFilter\ChatpadFilter.vcxproj
Get-Content src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj
Get-Content ChatpadWin11.sln
Select-String -Path src\driver\ChatpadFilter\* -Pattern 'ChatpadKmdfRequestOwner|CreateDormantObjectGraph|ActivationRequestOwner'
```
