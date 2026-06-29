# Next Task

## Current state

- **Branch:** `test/protocol-fixtures` / HEAD `664aa66bfb5bfca8c8319…`
- **Uncommitted changes:** 7 modified files + 3 untracked files (ChatpadProtocol.vcxproj, ChatpadProtocolTests.vcxproj, Test-ChatpadProtocol.ps1)
- **All builds verified passing:** Parser 85/85, Protocol 85/85 (Debug+Release), Driver 0/0 (Debug+Release)
- **Driver isolation proven:** ChatpadFilter does not link ChatpadProtocol.lib

## Next recommended objective

Commit the working tree changes together (implementation + documentation) and push the branch.

## Required branch and starting commit

- Branch: `test/protocol-fixtures`
- Starting commit: `664aa66bfb5bfca8c8319…`

## Preconditions

- All builds pass (verified above)
- No uncommitted changes beyond those listed (7 modified + 3 untracked)

## Safety restrictions

- Do not install, sign, or deploy the driver
- Do not commit artifacts under `artifacts/` or `.vs/`
- Do not modify `legacy/`
- Ensure prohibited commit `6502452` is not ancestor of HEAD

## Acceptance criteria

- Commit message describes the protocol integration work
- All modified files are staged and committed
- Branch is pushed to remote
- Final `git status` shows clean working tree

## Commands the next agent should inspect first

```bash
git diff --stat
git diff HEAD -- ChatpadWin11.sln
git diff HEAD -- Directory.Build.props
git diff HEAD -- tools/Build-Driver.ps1
git diff HEAD -- src/driver/ChatpadFilter/ChatpadFilter.vcxproj
git diff HEAD -- src/protocol/ChatpadProtocol/README.md
git diff HEAD -- tests/protocol/README.md
git diff HEAD -- docs/BUILDING.md
git diff HEAD -- tools/Test-ChatpadProtocolParser.ps1
```
