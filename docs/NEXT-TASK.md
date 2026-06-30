# Next Task

## Current state

- Current branch: `feature/offline-kmdf-production-integration-design`.
- Expected checkpoint: pushed `docs: define kmdf production integration`
  commit created from `39b2356c9193ea33d10d5c689e565a88a2e586c3`.
- The authoritative production-integration design is
  [Windows 11 KMDF Production Integration Design](WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md).
- The isolated dormant implementation is complete, but production linkage has
  not begun.
- No request-owner helper has executed. No production source embeds the owner,
  initializes it, invokes orchestration, creates a WDF request-owner object, or
  discovers a target.

## Recommended next objective

Implement only the first production integration slice: project-linkage-only
dormancy for `ChatpadKmdfRequestOwnerContext`.

Do not embed the owner, initialize storage, invoke helpers, create WDF objects,
change callbacks, run the driver, or touch hardware.

## Required branch and starting commit

Start from the pushed `feature/offline-kmdf-production-integration-design`
checkpoint. Verify the exact HEAD, parent, subject, upstream, and clean
worktree/index before editing.

## Preconditions

1. Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, the latest `docs/WORKLOG.md` entry, and
   `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`.
2. Inspect `ChatpadFilter.vcxproj`,
   `ChatpadKmdfRequestOwnerContext.vcxproj`, `ChatpadWin11.sln`, and current
   linker/include settings.
3. Confirm current production code still has no owner field, no context header
   include, no initializer call, no orchestration call, and no request-owner
   WDF object-management imports.

## Safety restrictions

- Modify only project/solution files and directly relevant Markdown if the
  task explicitly authorizes the linkage slice.
- Do not modify `.c` or `.h` source for linkage-only dormancy.
- Do not invoke owner initialization, orchestration, rollback, target
  discovery, request formatting, request submission, completion, cancellation,
  signing, packaging, staging, installation, loading, device enumeration, or
  hardware interaction.
- Do not run source, driver, kernel, InfVerif, Inf2Cat, package, installation,
  or hardware tests unless the next task explicitly authorizes exact commands.

## Acceptance criteria

- `ChatpadFilter` has the exact project dependency selected by the design.
- No owner field is embedded.
- No request-owner helper is referenced by production source.
- No `/INCLUDE` directive is added for request-owner helpers.
- Final driver import/symbol inspection, if build validation is authorized,
  shows no unexpected WDF object-management imports from an unused static
  library.
- Runtime behavior remains unchanged.
- Generated logs remain ignored beneath `artifacts\`.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
git diff --exit-code
git diff --cached --exit-code
Get-Content docs\WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md
Get-Content src\driver\ChatpadFilter\ChatpadFilter.vcxproj
Get-Content src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj
Get-Content ChatpadWin11.sln
Select-String -Path src\driver\ChatpadFilter\* -Pattern 'ChatpadKmdfRequestOwner|CreateDormantObjectGraph|ActivationRequestOwner'
```
