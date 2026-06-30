# Offline Production Linkage Evidence Correction

This checkpoint completes the retained-evidence record for the audited
project-linkage-only KMDF production checkpoint. It changes documentation and
evidence metadata only.

## Purpose and non-scope

The correction adds exact wrapper or command names, configurations, retained
log paths, transcript SHA-256 values, observed results, and assertion or
warning/error counts where applicable. It also adds hash-bound transcripts for
repository safety, Markdown links, JSON parsing, and unstaged/staged diff
checks.

No linkage implementation, source, header, project, solution, script, test,
INF, signing, package, deployment, recovery, or hardware file changed. No build
or regression suite was rerun. No helper was invoked and no WDF object was
created or deleted.

## Repository state

- Starting branch: `feature/offline-kmdf-production-linkage`.
- Starting commit: `90ca13f8babfc0c8fd1d14c998c1719e4788a5f6`.
- Starting parent: `033bd4fb4deff662ee9e3c2144d10decd27c8a03`.
- Starting subject: `build: link dormant request owner library`.
- Correction branch: `feature/offline-production-linkage-evidence-fix`.
- Manifest:
  [production-linkage-manifest.json](evidence/production-linkage-manifest.json).

## Audit findings corrected

The prior manifest retained hashes for all build and regression transcripts but
did not give regression transcript paths or exact commands. Repository safety,
Markdown links, JSON parsing, and diff checks were stated without their own
hash-bound retained transcripts. The correction adds one backward-compatible
`evidence_entries` array while preserving the original validation, log,
artifact, symbol/import, toolchain, and safety fields.

The array contains Debug and Release entries for:

- request-owner context compile check;
- driver build;
- full solution;
- production-linkage semantic guard;
- request-owner model (`5002/5002`);
- protocol (`610/610`);
- transport (`186/186`);
- filter lifecycle (`109/109`);
- control setup (`141/141`);
- protocol kernel compatibility;
- WDF control setup.

All 22 historical retained paths exist and their SHA-256 values match the
hashes already recorded by the production-linkage checkpoint. No historical
log was regenerated or substituted.

## New retained transcripts

The following deterministic ignored transcripts were generated beneath
`artifacts/logs`:

| Check | Relative path | SHA-256 |
| --- | --- | --- |
| Repository safety | `artifacts/logs/production-linkage-evidence-repository-safety.transcript.log` | `81E7D980CCC45AF9E6DFDBDC6F25D072A0F4BF0FE613872DA9C90D1A2ED2AA06` |
| Markdown links | `artifacts/logs/production-linkage-evidence-markdown-links.transcript.log` | `DECE079888628A59FB1B50E6147F93EB0F7815838A46FF4D2C46175614B20094` |
| Final manifest JSON parse | `artifacts/logs/production-linkage-evidence-json-parse.transcript.log` | `C63977C78466266948B7CE9160539522E628FAA7D7A26C8B463C1C472FE302DD` |
| Unstaged diff check | `artifacts/logs/production-linkage-evidence-unstaged-diff-check.transcript.log` | `879CF54F2E5535E47BFC633490538DB3C9235C44A4ADF00B3EF23CCBED7823B3` |
| Staged diff check | `artifacts/logs/production-linkage-evidence-staged-diff-check.transcript.log` | `A399BC4AEA5F2817A54B8874BC2037D844428042FB7EB13FA30FF30F253D092D` |

The transcript files remain untracked and ignored. The Git commit containing
the manifest binds the tracked evidence description; the manifest does not
contain its own correction commit hash.

## Artifact revalidation

No artifact was rebuilt. Read-only size, hash, and signature checks confirmed:

- Debug driver: 15,872 bytes,
  `198DD46B310A041EC40C6A4B5CE97A3B851DDD95CD300D167B929103580929D2`,
  `NotSigned`.
- Release driver: 12,288 bytes,
  `040ACC31C1464320037D957777A1C092FD2030D4F2EAE0D10397016CF00F3445`,
  `NotSigned`.
- Debug context library: 109,382 bytes,
  `8FCE8EB6F648ED555C22143642B4E035957E524F84422990BBC6CED053BEA72E`.
- Release context library: 93,790 bytes,
  `CC4730A4A402079A7EA3557DEADC1E69F626F5C5892AD3FC7031308EEA234DAE`.

## Remaining limitations

The production-linkage semantic wrapper remains a targeted XML, text, regex,
import, and symbol guard. It does not independently prove complete C macro
expansion, callback reachability, or every linker extraction path.

The historical build and regression transcripts prove only the offline
commands recorded at the linkage checkpoint. This correction did not execute
the driver, invoke the dormant helper, create or delete WDF objects, or prove
runtime behavior on Windows or hardware.

The corrected evidence was independently audited before the separately
authorized owner-embedding and ordinary-initialization checkpoint recorded in
[Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
This correction remains historical evidence and does not authorize dormant
orchestration.
