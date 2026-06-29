# Next Task

## Current continuation point

Branch `feature/offline-extension-inf-prototype` contains the isolated
source-controlled extension INF, PowerShell 5.1 static-validation wrapper,
narrow repository-safety exception, documentation, and verified unsigned
Debug/Release driver regressions. The task commit subject is
`build: add offline extension inf prototype`; use the final commit reported for
this task and verify it equals
`origin/feature/offline-extension-inf-prototype` before branching.

The INF passes WDK declarative validation and semantic guards. It declares
future catalog identity but no CAT or package exists.

## Recommended objective

Create an isolated offline package-layout validation under ignored
`artifacts/`, copy only the validated INF and matching unsigned driver into
that disposable layout, and run Inf2Cat to test catalog generation for the
declared Windows 11 AMD64 target.

This requires new explicit authorization because it creates generated package
content and a catalog. Stop before signing, staging, installation, loading, or
device access.

## Required branch and starting commit

- Create a dedicated feature branch from the final
  `feature/offline-extension-inf-prototype` commit.
- Require exact local/remote starting equality and a clean tree.
- Require prohibited commit `6502452` not to be an ancestor.

## Preconditions

- Re-read `AGENTS.md`, continuation documents, prototype README/INF, validation
  wrapper, recovery design, and current WDK Inf2Cat help.
- Obtain explicit authorization for offline package-layout and CAT generation.
- Verify `InfVerif`, semantic guards, repository safety, and both unsigned
  driver builds still pass.
- Resolve the exact Inf2Cat OS identifier from installed tool help; do not
  guess it.

## Safety restrictions

- Generated package layout and CAT only beneath ignored `artifacts/`.
- No tracked CAT, package, certificate, key, binary, or generated output.
- No signing, certificate creation/import, trust-store, Secure Boot/HVCI/BCD,
  staging, PnPUtil/DevCon/DISM mutation, Driver Store, registry, service,
  installation, load, device restart, elevation, network, or hardware action.
- No changes to `legacy/`, `ChatpadFilter.vcxproj`, runtime driver behavior, or
  external skills.

## Acceptance criteria

- Package input uses the exact validated INF hash and matching driver hash.
- Inf2Cat runs from an argument array with an installed, inspected OS target.
- Generated CAT and logs remain only beneath `artifacts/`.
- Catalog-generation warnings/errors and exit code are reported exactly.
- No signing occurs and generated CAT is explicitly untrusted/unsigned.
- Repository safety, driver isolation, and clean tracked state remain intact.

## Inspect first

- `prototypes/inf/ChatpadFilterExtension/README.md`
- `prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf`
- `tools/Test-ChatpadFilterInfPrototype.ps1`
- `tools/Test-RepositorySafety.ps1`
- `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`
- `docs/PROJECT-STATE.md`
- installed `Inf2Cat.exe /?`
