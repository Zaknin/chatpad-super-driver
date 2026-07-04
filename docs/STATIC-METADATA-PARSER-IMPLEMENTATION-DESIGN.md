# Static Metadata Parser Implementation Design

## 1. Status and authorization boundary

- Design transition base:
  `382aa85980408939a93043583b48e942ebfbf018`.
- Accepted metadata-review design audit:
  `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`.
- Accepted static metadata-parser implementation design audit:
  `468e8679388481e923a37a985055046f72480921`.
- Current gate:
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation: `IMPLEMENTED_PENDING_AUDIT`.
- Parser execution: `SYNTHETIC_FIXTURES_ONLY`.
- Metadata review: `NOT_PERFORMED`.

This document's implementation design passed independent read-only audit. A
separate implementation task added the static parser source and validated it
only against synthetic fixtures. That implementation does not authorize parser
execution against the real compiled artifact, artifact opening, artifact
parsing, artifact hashing, metadata review, assembly loading, reflection,
execution, native invocation, device query, Windows mutation, or driver
actions.

## 2. Investigation and technology decision

The repository and installed toolchain were inspected as source text and tool
inventory only. The compiled artifact was not inspected.

| Candidate | Loads assembly | Runtime reflection | Executes artifact | Byte-only capability | Current availability | Decision and risks |
| --- | --- | --- | --- | --- | --- | --- |
| `System.Reflection.Metadata` with `PEReader` and `MetadataReader` | No, when constructed only over a file stream | No | No | Yes | Available in the installed .NET 9 reference/runtime framework; no repository implementation exists | **Preferred.** Microsoft-maintained, MIT-licensed .NET component, strongly typed PE/CLI metadata APIs, no external package required when targeting the installed framework. Pin the SDK/runtime and treat malformed input as hostile because Microsoft warns that `PEReader` is not designed for untrusted input. |
| PowerShell-hosted .NET using the same APIs | Not inherently | Not inherently | Not inherently | Yes | PowerShell and .NET are available | Not preferred. `Add-Type`, ambient assembly resolution, and host variability widen the proof surface. A small isolated console tool is more deterministic and auditable. |
| dnlib | No runtime load is required for normal file/byte readers | No runtime reflection is required | No | Yes | Not present | Rejected. MIT license, but it is a broad reader/writer/resolver with PDB, rewrite, signing, and optional native-reader surfaces. It adds dependency pinning, resolver, offline restore, and misuse risk beyond the allowlist. |
| Mono.Cecil | No runtime load is required for normal file readers | No runtime reflection is required | No | Yes | Not present | Rejected. MIT-licensed inspection and rewrite library, but its broad mutation/resolution surface, external dependency, version pinning, and offline restore requirements are unnecessary. |
| `ildasm` | Does not use CLR assembly loading for its normal disk-file workflow | No | No | Reads PE/CLI files | Not found in the current Windows SDK/tool search | Rejected. External-process and version-dependent text output, broader IL/resource extraction, possible extra output files, and no stable repository-controlled JSON contract. |
| `ilspycmd` | Static decompiler workflow, not CLR execution of the target | No runtime reflection required for normal use | No | Reads assemblies from disk | Not installed and not cached | Rejected. MIT license, but decompilation is much broader than metadata inspection and adds a large external dependency and runtime/version surface. |
| `dumpbin` | No managed assembly load | No | No | Reads PE bytes | MSVC copies exist but are not on `PATH`; repository uses are for native driver/object evidence | Rejected. It is not a managed CLI metadata contract, exposes version-dependent text, and cannot provide the required strongly typed P/Invoke metadata proof. |
| Custom PE/CLI byte parser | No | No | No | Yes | No implementation exists | Rejected. Reimplementing ECMA-335 parsing adds unnecessary bounds, integer-overflow, malformed-table, signature-decoding, and maintenance risk. |
| Existing repository-native tool | N/A | N/A | N/A | N/A | None | No qualifying parser exists. Existing tools are guards, compile-only evidence, native `dumpbin` workflows, or documentation. |

The preferred future implementation is a source-controlled .NET 9 console
tool using only `System.IO.FileStream`,
`System.Reflection.PortableExecutable.PEReader`, and
`System.Reflection.Metadata.MetadataReader`. It must use framework-provided
references only, remain outside production solutions/projects, and emit one
deterministic JSON document.

Official references:

- <https://learn.microsoft.com/en-us/dotnet/api/system.reflection.portableexecutable.pereader>
- <https://learn.microsoft.com/en-us/dotnet/api/system.reflection.metadata.methoddefinition.getimport>
- <https://learn.microsoft.com/en-us/dotnet/api/system.reflection.methodimportattributes>
- <https://learn.microsoft.com/en-us/dotnet/api/system.reflection.portableexecutable.corheader>
- <https://learn.microsoft.com/en-us/dotnet/framework/tools/ildasm-exe-il-disassembler>
- <https://learn.microsoft.com/en-us/cpp/build/reference/dumpbin-reference>
- <https://github.com/dotnet/runtime>
- <https://github.com/0xd4d/dnlib>
- <https://github.com/jbevain/cecil>
- <https://github.com/icsharpcode/ILSpy>

## 3. Future implementation layout

The separately authorized implementation task added:

- `tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj`;
- parser source under `tools/StaticMetadataParser/`;
- a JSON evidence schema at
  `docs/evidence/static-metadata-parser-evidence-schema-v1.md`;
- synthetic fixture generation and validation in
  `tools/Test-ChatpadStaticMetadataParser.ps1`;
- a static prohibited-pattern guard in the validation harness.

The project targets `net9.0`, is absent from `ChatpadWin11.sln` and every
production project graph, have no project reference to production driver or
native-interoperability projects, has no post-build/run target, and uses no
third-party package.

Implementation, build, and synthetic testing have occurred only in this parser
scope. First use against the real compile-only artifact remains a separate
authorization boundary after independent implementation audit.

## 4. Input and identity contract

The future parser accepts exactly one explicit absolute `.dll` path and one
explicit accepted compile-evidence JSON path. It must reject:

- relative paths, globs, directories, alternate data streams, non-`.dll`
  inputs, reparse points, and paths outside an explicitly allowed ignored
  compile-only or audit root;
- missing, non-regular, zero-length, or oversized inputs;
- evidence not using
  `chatpad-native-interop-compile-only-validation-v2`;
- evidence that does not identify the input as an ignored
  `raw_file_bytes` compile output;
- ambiguous or multiple candidate DLL records;
- an evidence path/hash mismatch;
- any request for dependency, PDB, resource, or sibling-file discovery.

The identity source is reference-only in this phase:

- accepted evidence:
  `docs/evidence/native-interop-compile-only-validation.json`;
- accepted validation ID:
  `native-interop-compile-only-20260703T194533Z`;
- accepted primary-DLL SHA-256 recorded in existing evidence:
  `77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862`.

This task does not re-hash or open the artifact. A future first-use task must
explicitly authorize raw artifact hashing and reading before the parser may
verify that recorded identity.

## 5. File-reading and containment contract

When later authorized, the parser must:

1. canonicalize and validate the evidence path and artifact path before open;
2. reject reparse points and path changes between validation and open;
3. open one regular file read-only, without write/delete sharing;
4. enforce a documented byte-size ceiling before allocation;
5. use the safe `PEReader(Stream, PEStreamOptions)` surface, not pointer,
   loaded-image, memory-mapped, or unsafe constructors;
6. avoid OS image loading, assembly resolution, metadata load contexts, PDB
   discovery, resource extraction, and sibling-file access;
7. dispose the stream and reader deterministically;
8. fail closed on I/O, malformed-image, bounds, decoding, timeout, memory, or
   unexpected exceptions;
9. emit no file other than the caller-selected JSON evidence path.

The caller must run the future parser with a bounded timeout and an isolated
ignored output directory. Timeout, crash, partial JSON, or extra files are
failures.

## 6. Allowed PE/CLI inspection

The parser may read only:

- DOS/PE/COFF and optional-header identity needed for PE kind and machine;
- CLI header presence, flags, metadata directory, and entry-point token;
- metadata-root presence and version;
- module and assembly definitions;
- assembly name, version, culture, public-key data/token if present;
- targeted `TargetFrameworkAttribute` metadata blob;
- type-definition namespace/name and nesting;
- method-definition name and signature metadata;
- implementation-map/P/Invoke rows through `MethodDefinition.GetImport()`;
- import module name, entry-point name, exact-spelling, character-set,
  set-last-error, and calling-convention flags;
- counts and deterministic allowlist comparisons.

It must not decode or inspect method bodies, execute IL, instantiate custom
attributes, resolve referenced assemblies/types/methods, read PDBs, extract
resources, or inspect unrelated files.

## 7. Expected declaration contract

The future review expects exactly 13 P/Invoke method definitions:

| Module | Entry points |
| --- | --- |
| `setupapi.dll` | `SetupDiCreateDeviceInfoList`, `SetupDiDestroyDeviceInfoList`, `SetupDiOpenDeviceInfoW`, `SetupDiGetDeviceInstanceIdW`, `SetupDiGetDevicePropertyW`, `SetupDiGetDeviceRegistryPropertyW`, `SetupDiBuildDriverInfoList`, `SetupDiDestroyDriverInfoList`, `SetupDiEnumDriverInfoW`, `SetupDiGetDriverInfoDetailW`, `SetupDiGetDriverInstallParamsW`, `SetupDiSetSelectedDriverW` |
| `newdev.dll` | `DiInstallDevice` |

Module and entry-point comparisons are ordinal, case-insensitive for module
names and ordinal, case-sensitive for entry-point names. Duplicate rows,
forwarded/unexpected modules, unexpected methods, missing exact-spelling or
set-last-error metadata, incompatible character-set/calling-convention flags,
or any executable CLI entry-point token are defects. The expected declaration
inventory must come from an audited, immutable design constant, never from the
artifact itself.

## 8. Absolute API and behavior prohibitions

Future parser source and transitive dependencies must not use:

- `Assembly.Load*`, `Assembly.ReflectionOnlyLoad*`, `MetadataLoadContext`,
  runtime `Type`, `MethodInfo`, `FieldInfo`, `PropertyInfo`, or
  `CustomAttributeData` inspection of the artifact;
- `Activator`, `Delegate.DynamicInvoke`, method invocation, emitted code,
  expression compilation, `Add-Type`, or `dotnet exec`;
- `[DllImport]`, `LibraryImport`, `NativeLibrary`, `LoadLibrary`,
  `GetProcAddress`, entry-point resolution, marshaled delegates, or native
  invocation;
- `Process.Start`, shell execution, PowerShell invocation, device tools,
  SetupAPI/Newdev/CfgMgr32 calls, WMI/CIM device queries, registry/services,
  certificates/keys/credentials, scheduled tasks, boot configuration, or
  Windows mutation;
- driver build, link, sign, CAT generation, package, stage, install, load,
  unload, bind, restore, restart, enable, disable, or remove operations.

## 9. Required prohibited-pattern guard

A future implementation task must add a fail-closed AST/source guard that:

- allows only the exact `System.Reflection.Metadata` and
  `System.Reflection.PortableExecutable` namespaces;
- rejects runtime assembly/reflection APIs and all APIs in section 8;
- rejects P/Invoke declarations and native-library resolution;
- rejects process creation, network access, environment-based tool discovery,
  file enumeration, recursive traversal, and writes outside the one evidence
  output;
- rejects project references, post-build targets, runtime identifiers,
  self-contained publishing, unsafe code, and production solution inclusion;
- proves the parser project has no production/native/driver dependency edge;
- reports exact file, line, rule, and match for every defect.

Text mentions in this design document are explanatory and are not executable
guard violations. The guard must inspect syntax/AST or project XML rather than
using an unqualified repository-wide string count.

## 10. Future JSON evidence model

Schema identifier:
`chatpad-static-metadata-parser-evidence-v1`.

Required top-level fields:

- `schema_version`, `generated_utc`, `result`, `result_code`;
- `parser_tool_identity`, `parser_source_commit`, `parser_version`,
  `parser_target_framework`, `system_reflection_metadata_version`;
- `input_artifact_path`, `input_artifact_path_classification`;
- `input_identity_source`, `compile_evidence_path`,
  `compile_evidence_schema`, `compile_evidence_validation_id`,
  `recorded_artifact_sha256`, `hash_verification_status`;
- strict Boolean `artifact_bytes_read`, `artifact_hash_computed`,
  `metadata_parsed`, `static_only`;
- strict Boolean `no_load_guarantee`, `no_runtime_reflection_guarantee`,
  `no_execution_guarantee`, `no_native_invocation_guarantee`,
  `no_device_query_guarantee`, and `no_windows_mutation_guarantee`;
- strict Boolean `assembly_load_occurred`,
  `runtime_reflection_occurred`, `compiled_artifact_execution_occurred`,
  `native_dll_load_occurred`, `entry_point_resolution_occurred`,
  `native_invocation_occurred`, `setupapi_newdev_invocation_occurred`,
  `device_query_occurred`, `hardware_access_occurred`,
  `windows_mutation_occurred`, and `driver_actions_occurred`;
- `pe_cli_summary`, `assembly_identity`, `artifact_target_framework`,
  `type_definitions`, `method_definitions`, `pinvoke_summary`;
- `expected_declaration_count`, `actual_declaration_count`,
  `expected_modules`, `actual_modules`, `declaration_checks`;
- `entry_point_absence_check`, `diagnostics`, `defects`,
  `safety_counters`.

`pe_cli_summary` must include PE kind, COFF machine, CLI-header presence,
metadata presence, module kind, CLI flags, and entry-point token presence.
`pinvoke_summary` must contain only deterministic metadata values and must be
sorted by module then entry-point. Every defect contains `code`, `location`,
`expected`, `actual`, and `message`.

Safety counters must include artifact open/read/hash/parse, assembly load,
reflection, execution, native DLL load, entry-point resolution, native/API
invocation, SetupAPI/Newdev invocation, device query, hardware access, Windows
mutation, and every driver action. A successful static review requires all
prohibited counters to be `0`; artifact read/hash/parse counters may become
nonzero only in a future task that explicitly authorizes those exact actions.

## 11. Determinism and failure model

- JSON property order and array sort order are fixed by schema.
- Timestamps are informational and excluded from semantic identity.
- Paths are repository-relative in durable evidence; absolute paths are
  diagnostic only and must not expose private machine data.
- String comparison rules are explicit and culture-invariant.
- Unknown metadata tables, flags, encodings, architectures, modules, entry
  points, or parser versions fail closed.
- Truncated, malformed, oversized, mixed-mode, ReadyToRun, native-entry-point,
  multi-module, or executable-entry-point images fail closed unless a later
  audited design explicitly allows them.
- Parser warnings cannot be reclassified as pass; any diagnostic severity
  other than informational makes the result blocked or failed.
- Partial evidence, exception-only output, missing counters, non-Boolean safety
  fields, duplicate JSON properties, or extra undeclared properties fail.

## 12. Independent design-audit acceptance

The independent read-only audit of this document and the gate/manifest
transition returned `AUDIT PASS` at
`468e8679388481e923a37a985055046f72480921`. Accepted evidence:

- artifact inventory:
  `artifacts/logs/independent-static-metadata-parser-design-audit-468e867/artifact-inventory.json`,
  size `54161` bytes, SHA-256
  `D43213A552CF61E793BABD2792D6B3329706EF9F2DB3DC46D401B66307725B6F`;
- audit summary:
  `artifacts/logs/independent-static-metadata-parser-design-audit-468e867/audit-summary.json`,
  size `14996` bytes, SHA-256
  `A1A83F8C7A818B45D2A19A2C10C9206FE0C38CB8335485E17E2124BCEFCDB2C5`.

The audit verified:

- no parser source, project, executable, or output was added;
- the preferred API operates on PE/CLI bytes without assembly loading,
  runtime reflection, execution, dependency resolution, or native invocation;
- the technology matrix and local availability claims are reproducible;
- the input, containment, allowlist, evidence, determinism, and failure
  contracts are complete and fail closed;
- all current manifest safety fields remain strict Booleans;
- artifact opening, parsing, and hashing remain unauthorized and unperformed;
- live readiness remains `BLOCKED`, native execution remains
  `NOT_IMPLEMENTED`, and the runtime blocker remains unchanged.

The current gate is
`BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`. The next task
must independently audit the parser implementation. Parser execution against
the real artifact, metadata review, compiled-artifact opening/parsing/hash
verification, loading, reflection, execution, native invocation, device query,
Windows mutation, and driver actions remain unauthorized unless separately and
explicitly allowed after that audit.
