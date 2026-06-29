# Decisions

*Only durable technical or workflow decisions go here.*

## 2026-06-29 — Protocol integration into build system

- **Decision:** Build ChatpadProtocol as a dependency of ChatpadFilter using separate MSBuild invocations (not solution-level Build).
- **Rationale:** Building the solution with `/t:Build` on ChatpadFilter would route ChatpadProtocol's intermediate output into ChatpadFilter's IntDir, causing PDB collisions and incorrect output paths. Separate MSBuild calls ensure each project's own IntDir/OutDir is respected.
- **Alternatives rejected:** Building the solution file directly with `/t:Build`.
- **Consequences:** `Build-Driver.ps1` now builds ChatpadProtocol first, then ChatpadFilter. Both use `/p:RepoRoot` and pass explicit `OutDir`/`IntDir` to MSBuild. Directory.Build.props adds a `RepoRoot` property. `ChatpadFilter.vcxproj` SignMode remains Off.

## 2026-06-29 — SignTool detection expansion

- **Decision:** Expand SignTool execution detection in `Build-Driver.ps1` to match MSBuild diagnostic log patterns including `:` after target name, `Task`/`Using` prefix, `SIGNTASK:`, and explicit `signtool.exe` paths.
- **Rationale:** The original regex only matched target names with `(")` suffix, missing the `(:)` form present in diagnostic logs.
- **Consequences:** `Build-Driver.ps1` now reliably detects active WDK signing tasks in MSBuild diagnostic output.

## 2026-06-29 — PowerShell 5.1 compatibility

- **Decision:** Replace `[System.Text.UTF8Encoding]::new($false)` with `[System.Text.Encoding]::UTF8` and use `.NET` SHA256 fallback for `Get-FileHash` in `Test-ChatpadProtocolParser.ps1`.
- **Rationale:** `[System.Text.UTF8Encoding]::new(false)` is not available in PowerShell 5.1 (requires .NET Framework 4.6+). The .NET fallback ensures compatibility.
- **Consequences:** Test scripts work across PowerShell 5.1+ without version-specific syntax.
