# Agent Protocol

Every agent (Hermes, Ornith, Codex, or another coding agent) MUST follow this workflow for every task in this repository.

---

## START-OF-TASK ROUTINE

1. Read, in this order:
   * `AGENTS.md`
   * `docs/PROJECT-STATE.md`
   * `docs/DECISIONS.md`
   * `docs/NEXT-TASK.md`
   * The most recent relevant entries in `docs/WORKLOG.md`

2. Inspect the real repository state:
   * Current branch;
   * HEAD commit;
   * `git status`;
   * Relevant recent history;
   * Files and outputs involved in the requested task.

3. Compare the documentation with the actual repository.

4. If documentation is stale:
   * Correct it before relying on it;
   * Record the discrepancy in `docs/WORKLOG.md`.

5. Verify the previous task's claimed result when practical. Never assume that an earlier agent's report is correct merely because it sounds complete.

6. Do not begin implementation until the current repository state and task preconditions are understood.

---

## DURING-TASK ROUTINE

1. Keep changes limited to the requested scope.
2. Preserve all safety restrictions and architectural decisions.
3. Validate partial results as work progresses.
4. Never hide, suppress, or reinterpret failed commands as success.
5. Do not modify generated files manually when the source or build configuration should be fixed instead.
6. Do not install, load, sign, package, deploy, or execute a driver unless a later task explicitly authorizes that exact action.
7. Never modify files under `legacy/`; they are an immutable historical reference.
8. Keep generated outputs and diagnostic logs under ignored `artifacts/`.
9. Do not commit secrets, machine-specific private information, certificates, binaries, or generated build outputs.

---

## END-OF-TASK ROUTINE

Before declaring a task complete:

1. Inspect the complete diff.

2. Run all applicable validation and safety checks.

3. Check `git status`.

4. Update `docs/PROJECT-STATE.md` with:
   * Current branch;
   * Current HEAD after commit, or expected commit if the log update is part of that commit;
   * Verified build/toolchain status;
   * Current implementation state;
   * Unresolved blockers;
   * Safety state.

5. Append a new timestamped entry to `docs/WORKLOG.md` containing:
   * Task title and objective;
   * Starting branch and commit;
   * Summary of investigation;
   * Files created, modified, or removed;
   * Important implementation details;
   * Commands and tests run;
   * Exact pass, fail, or blocked results;
   * Generated artifact locations, without committing the artifacts;
   * Commit hash and pushed branch when applicable;
   * Remaining risks or limitations.

6. Update `docs/DECISIONS.md` only when a durable technical or workflow decision was made. Each entry must include:
   * Date;
   * Decision;
   * Rationale;
   * Alternatives rejected;
   * Consequences.

7. Replace `docs/NEXT-TASK.md` with:
   * Exact current state;
   * The next recommended objective;
   * Required branch and starting commit;
   * Preconditions;
   * Safety restrictions;
   * Acceptance criteria;
   * Commands or files the next agent should inspect first.

8. Ensure the continuation documents contain no unsupported claims.

9. Commit the implementation and continuity updates together unless the task explicitly requires a separate documentation-only commit.

10. Push only the requested branch.

---

## FINAL RESPONSE ROUTINE

Every final response must report:

* Objective completed;
* Branch;
* Commit hash;
* Pushed remote branch;
* Files changed;
* Validation results;
* Unresolved blockers;
* Final git status;
* Confirmation of any prohibited actions that were not performed;
* Exact recommended next task.

---

## DOCUMENT FORMAT

* `docs/PROJECT-STATE.md` should be concise and represent only current truth.
* `docs/WORKLOG.md` should be append-only. Do not rewrite or delete valid historical entries. Corrections must be added as new entries explaining the earlier mistake.
* `docs/DECISIONS.md` should contain only durable decisions, not ordinary implementation notes.
* `docs/NEXT-TASK.md` should describe only the next continuation point and may be replaced after each task.
