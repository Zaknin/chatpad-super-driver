# Next Task

## Objective

Define the next separately authorized native SetupAPI/Newdev adapter opening
without executing it. This should be a design-and-gate task only unless the
user explicitly authorizes implementation.

## Required starting point

- Branch: `feature/runtime-bringup-exact-instance-contract-remediation`
- Starting commit: the independent-audit closeout commit containing this file.
- Before any work, verify a clean tree, configured upstream, local/remote
  equality, exact ancestry from
  `9b380ef6e070311d682866a5f130b51a44f8485a`, and that
  `d22ba050a6f5fea0ab9e8a71470c90a474d7b548` is an ancestor.

## Current state

- Offline exact-instance remediation is implemented and independently
  audited as `PASS`.
- Authoritative validation remains offline/synthetic. The readiness evidence
  still reports live readiness as `BLOCKED`, current gate as
  `BLOCKED_PENDING_INDEPENDENT_AUDIT`, capability blocker as
  `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`, live adapter status as
  `NOT_IMPLEMENTED`, and live authorization as `false`.
- Audit evidence is ignored under `artifacts/logs/` and must not be committed.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this
  file, and the latest `docs/WORKLOG.md` entry.
- Inspect the exact-instance contracts and orchestrator before proposing any
  native boundary:
  - `tools/ExactInstance/ChatpadExactInstance.Contracts.psm1`
  - `tools/ExactInstance/ChatpadExactInstance.Orchestrator.psm1`
  - `tools/Invoke-ChatpadExactInstanceBindingRestoration.ps1`
  - `docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`
  - `docs/evidence/runtime-bringup-readiness-manifest.json`

## Safety restrictions

- No build, signing, CAT generation, packaging, staging, driver-store
  mutation, installation, binding, loading, restoration, restart, reboot,
  device query, hardware access, Windows mutation, production source/INF
  change, frozen-binary change, or `legacy/` change.
- Do not implement the native adapter unless the user explicitly opens that
  scope in a later task.
- Keep malformed or exploratory evidence under ignored `artifacts/` only.

## Acceptance criteria

- Produce a concrete native-adapter authorization/design gate that preserves
  exact instance ID opening, adapter-returned canonical ID comparison, one
  retained device element, immutable driver-node identity, exact restoration,
  postcondition proof, and explicit manual-recovery blockers.
- Define required future audit evidence before any live mutation can be
  considered, including commands, logs, negative fixtures, and stop
  conditions.
- Keep live readiness blocked unless a separately authorized implementation
  and audit are both completed.
