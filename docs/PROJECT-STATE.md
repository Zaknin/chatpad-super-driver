# Project State

*Last updated: 2026-07-01 (orchestration taxonomy-contract correction)*

## Current state

- **Branch:** `feature/offline-kmdf-orchestration-taxonomy-contract-fix`.
- **Current implementation checkpoint:**
  `8b91eaf939252e038bd0970db261cc14b1089613`,
  `docs: align owner initialization state`.
- **Expected taxonomy-contract correction commit:** the commit containing this
  correction uses subject `docs: finalize orchestration taxonomy contract` and
  has parent `6f9f2750347ee6ecd50470261a6af0a859b53357`.
- **Historical owner-initialization checkpoint:**
  `a25d5637487ec6e4e7583a64dcec6c5192e06092`,
  `driver: initialize production request owner`.
- **Checkpoint record:**
  [Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
- **Correction record:**
  [Offline KMDF Owner Initialization Audit Corrections](OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md).
- **Evidence manifest:**
  [production-owner-initialization-manifest.json](evidence/production-owner-initialization-manifest.json).
- **Documentation consistency:** the production integration design and porting
  plan now distinguish original pre-integration design history, completed
  linkage/owner-embedding/ordinary-initialization slices, current production
  reality, and remaining future integration.
- **Orchestration invocation design:**
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md)
  defines the future binding for invoking the existing dormant object-graph
  orchestrator after explicit pre-object validation and before lifecycle
  initialization. The first design failed independent audit because it
  overgeneralized early no-object failure semantics. The corrected design now
  distinguishes early argument/baseline rejection from post-baseline no-object
  stage failure. A second independent audit then found that the report/status
  taxonomy and caller report initialization wording were incomplete. The
  report-aware correction now binds `{ 0 }` caller initialization, synchronous
  local report lifetime, all supported result/report/mask/rollback categories,
  deterministic production status selection, and LTCG inspection limits. A
  third independent audit found that exact report fields `Result` and
  `ReadyPublicationAttempted` were not explicitly bound, the later
  `EvtDeviceAdd` lifecycle category was ambiguous, and the evidence contract
  omitted explicit highest/final-mask checks. This documentation-only
  correction binds all 19 report fields, deterministic lifecycle-failure
  subcases 22A and 22B, and explicit mask evidence. Orchestration is not
  implemented and the dormant source is unchanged. A fourth independent audit
  found that helper/validator/rollback-effect values remained implicit,
  section 28 omitted ten exact field names, and the semantic guard did not
  enforce source-level `ReadyPublicationAttempted` behavior. This
  documentation-only correction adds closed exact value sets, complete
  rollback-effect/origin matrices, a ready-field truth table, all 19 section-28
  field bindings, and exact ready-attempt guard requirements.
- **Production context:** `driver.h` includes the authoritative KMDF
  request-owner header and embeds exactly one
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`.
- **Initialization:** `ChatpadEvtDeviceAdd` calls the ordinary initializer
  once after scalar context setup. The initializer performs internal baseline
  validation, then `EvtDeviceAdd` performs one additional explicit pre-object
  integration-boundary validation before lifecycle initialization.
- **Project linkage:** the existing context static-library project reference
  is unchanged. `ChatpadFilter.vcxproj` compiles the portable request-owner
  model source directly as a WDK object and adds only the required include
  roots.
- **Owner baseline:** signature/version and pure model are initialized;
  initialization mask is exactly `MODEL_READY`; fixed two-byte arrays are
  zero; all WDF handles are null; `OWNER_READY`, `FAULTED`, creation bits,
  lifecycle obligations, and active operation state are absent.
- **Build/toolchain:** the retained build evidence still records Visual Studio
  Community 2022 17.14.35, MSVC 14.44.35207, SDK/WDK 10.0.26100.0, KMDF 1.15,
  and PASS results for Debug/Release context, driver, full-solution, semantic,
  kernel compatibility, WDF formatter, and regression checks. This correction
  pass did not rebuild or rerun regression suites.
- **Corrected evidence:** the production owner-initialization guard now runs in
  `Full` mode for Debug and Release against existing artifacts, records direct
  and inferred checks separately, verifies artifact/manifest containment, and
  states KMDF function-table import-inspection limits. Corrected manifest
  entries retain exact commands, working directories, paths, hashes, and
  results for the rerun guard, binary/member inspection, Markdown links, JSON
  parse, repository safety, and diff checks.
- **Binary state:** existing Debug driver is 20,992 bytes, SHA-256
  `FB9E9DD550BEF64B99BFAA74810A953A5B0DC12BB455869D7787FB657B565B8F`;
  existing Release driver is 14,336 bytes, SHA-256
  `9EA24A8B6BEB2796B9A1FF55A04486C8E3EB59B94A191AEA6F50B322531CBCE3`.
  Both are `NotSigned`.
- **Safety:** no production `.c/.h`, project/solution file, owner model,
  request-owner implementation, build output, INF, signing, package,
  deployment, recovery, D0, cleanup, removal, Windows state, device state, or
  hardware state was changed by this taxonomy-contract correction. No build,
  test, helper, orchestration, rollback, WDF object action, driver load, or
  hardware query ran.

## Unresolved blockers

- The finalized taxonomy-contract production orchestration invocation design
  requires another independent read-only documentation audit.
- Dormant orchestration invocation is designed but not implemented and remains
  unauthorized.
- Normal teardown, active-operation rundown, target discovery, request
  operations, D0 coordination, signing, staging, installation, loading, and
  hardware validation remain separate gates.
- No usable production driver exists.
