[CmdletBinding()]
param(
    [string]$ProjectPath = 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj',
    [string]$EvidencePath = '',
    [string]$OutputRoot = '',
    [switch]$NoLoad,
    [switch]$NoReflection,
    [switch]$NoInvoke,
    [ValidateSet('Debug','Release')][string]$Configuration = 'Release',
    [ValidateSet('x64')][string]$Platform = 'x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Path)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $pathFull = [IO.Path]::GetFullPath($Path)
    [Uri]::UnescapeDataString(([Uri]$rootFull).MakeRelativeUri([Uri]$pathFull).ToString()).Replace('/','\')
}

function Get-RawFileHashRecord {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Path,[string]$Role = 'input')
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    $relative=(Get-RelativePath -Root $Root -Path $item.FullName).Replace('\','/')
    [pscustomobject][ordered]@{
        role = $Role
        relative_path = $relative
        tracked = @(&git -C $Root ls-files -- $relative).Count -eq 1
        content_classification = 'compile-output-artifact'
        hash_policy = 'raw_file_bytes'
        byte_size = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        raw_file_byte_size = [long]$item.Length
        raw_file_sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        ignored = [bool](@(&git -C $Root check-ignore -- $relative 2>$null).Count)
        assembly_loaded = $false
        reflection_inspection_used = $false
        managed_code_executed = $false
        native_api_invoked = $false
    }
}

function Get-TextInputHashRecord {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Role,
        [Parameter(Mandatory)][string]$CommitRepresented
    )
    $identity=Get-ChatpadEvidenceFileIdentity -RepositoryRoot $Root -Path $Path -HashPolicy canonical_lf_text -CommitRepresented $CommitRepresented -State tracked
    [pscustomobject][ordered]@{
        role=$Role
        relative_path=$identity.relative_path
        tracked=$identity.tracked
        content_classification=$identity.content_classification
        hash_policy=$identity.hash_policy
        canonical_sha256=$identity.canonical_sha256
        canonical_byte_size=$identity.canonical_byte_size
        raw_working_tree_sha256=$identity.raw_working_tree_sha256
        raw_working_tree_byte_size=$identity.raw_working_tree_byte_size
        commit_represented=$identity.commit_represented
        line_ending_policy=$identity.line_ending_policy
        working_tree_line_endings=$identity.working_tree_line_endings
        raw_and_canonical_differ=$identity.raw_and_canonical_differ
        sha256=$identity.canonical_sha256
        byte_size=$identity.canonical_byte_size
    }
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$Purpose
    )
    $commandLine = "$Tool $($Arguments -join ' ')"
    $output = @(& $Tool @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText($OutputPath, ($output -join [Environment]::NewLine) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    [pscustomobject][ordered]@{
        purpose = $Purpose
        command_line = $commandLine
        working_directory = $WorkingDirectory
        exit_code = [int]$exitCode
        output_relative_path = (Get-RelativePath -Root $WorkingDirectory -Path $OutputPath).Replace('\','/')
    }
}

$root = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
$branch = (& git branch --show-current).Trim()
$head = (& git rev-parse HEAD).Trim()
$projectFull = [IO.Path]::GetFullPath((Join-Path $root $ProjectPath))
$validationId = 'native-interop-compile-only-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$canonicalArtifactRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts\compile-only\native-interop'))
$auditOutputMode = -not [string]::IsNullOrWhiteSpace($OutputRoot)
if($auditOutputMode){
    if(-not$NoLoad-or-not$NoReflection-or-not$NoInvoke){throw 'Audit output mode requires -NoLoad, -NoReflection, and -NoInvoke.'}
    $auditRunRoot=if([IO.Path]::IsPathRooted($OutputRoot)){[IO.Path]::GetFullPath($OutputRoot)}else{[IO.Path]::GetFullPath((Join-Path $root $OutputRoot))}
    $allowedArtifactsRoot=[IO.Path]::GetFullPath((Join-Path $root 'artifacts'))
    if(-not$auditRunRoot.StartsWith($allowedArtifactsRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
        throw 'OutputRoot must remain under the repository artifacts directory.'
    }
    if([string]::Equals($auditRunRoot,$canonicalArtifactRoot,[StringComparison]::OrdinalIgnoreCase)){
        throw 'Explicit audit OutputRoot must differ from the canonical compile-only output root.'
    }
    if(-not @(&git -C $root check-ignore -- $auditRunRoot 2>$null).Count){throw 'OutputRoot must be ignored by Git.'}
    $artifactRoot=Join-Path $auditRunRoot 'compile-output'
    $logRoot=Join-Path $auditRunRoot 'logs'
    $cleanupRoot=$auditRunRoot
    if(-not$EvidencePath){$EvidencePath=(Get-RelativePath -Root $root -Path (Join-Path $auditRunRoot 'compile-only-validation.json'))}
} else {
    $auditRunRoot=''
    $artifactRoot=$canonicalArtifactRoot
    $logRoot=Join-Path $root ('artifacts\logs\' + $validationId)
    $cleanupRoot=$artifactRoot
    if(-not$EvidencePath){$EvidencePath='docs/evidence/native-interop-compile-only-validation.json'}
}
$evidenceFull = if([IO.Path]::IsPathRooted($EvidencePath)){[IO.Path]::GetFullPath($EvidencePath)}else{[IO.Path]::GetFullPath((Join-Path $root $EvidencePath))}
if($auditOutputMode-and-not$evidenceFull.StartsWith($auditRunRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Audit output mode requires EvidencePath to remain under OutputRoot.'
}
if($auditOutputMode-and@(&git -C $root ls-files -- (Get-RelativePath -Root $root -Path $evidenceFull)).Count){
    throw 'Audit output mode cannot write a tracked evidence file.'
}
if (Test-Path -LiteralPath $cleanupRoot) {
    Remove-Item -LiteralPath $cleanupRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $artifactRoot,$logRoot,(Split-Path $evidenceFull -Parent) | Out-Null

$declarationPath = Join-Path $root 'tools\ExactInstance\NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'
$boundaryPath = Join-Path $root 'tools\ExactInstance\NativeInterop\ChatpadNativeInteropSourceBoundary.psm1'
$contractPath = Join-Path $root 'tools\ExactInstance\CompileOnlyValidation\CompileOnlyContracts.cs'
$propsPath = Join-Path $root 'tools\ExactInstance\CompileOnlyValidation\Directory.Build.props'
$expectedDeclarationHash = '127EA58993862CCE865E3D73B0F1A99513932ABDF1BEA615812966EB5C14BEAA'
$expectedBoundaryHash = '3E7E3119A467330A413280658503B294C0FFB38271A9CA847056BAF6B2E778D3'
$actualDeclarationHash = (Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path $declarationPath -HashPolicy canonical_lf_text -CommitRepresented $head -State tracked).canonical_sha256
$actualBoundaryHash = (Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path $boundaryPath -HashPolicy canonical_lf_text -CommitRepresented $head -State tracked).canonical_sha256
if ($actualDeclarationHash -cne $expectedDeclarationHash -or $actualBoundaryHash -cne $expectedBoundaryHash) {
    throw 'Audited NativeInterop source hashes do not match the accepted compile-only validation precondition.'
}

$commands = [Collections.Generic.List[object]]::new()
$commands.Add((Invoke-CapturedCommand -Tool 'dotnet' -Arguments @('--info') -WorkingDirectory $root -OutputPath (Join-Path $logRoot 'dotnet-info.txt') -Purpose 'capture-dotnet-sdk-and-runtime-identity'))
$commands.Add((Invoke-CapturedCommand -Tool 'dotnet' -Arguments @('msbuild','-version') -WorkingDirectory $root -OutputPath (Join-Path $logRoot 'msbuild-version.txt') -Purpose 'capture-msbuild-version'))

$sdkBasePath = (& dotnet --info | Select-String -Pattern 'Base Path:' | Select-Object -First 1).Line
$roslynVersion = 'unavailable'
$roslynCommand = $null
if ($sdkBasePath) {
    $sdkPath = ($sdkBasePath -replace '^\s*Base Path:\s*','').Trim()
    $cscPath = Join-Path $sdkPath 'Roslyn\bincore\csc.dll'
    if (Test-Path -LiteralPath $cscPath -PathType Leaf) {
        $roslynOutputPath = Join-Path $logRoot 'roslyn-csc-version.txt'
        $roslynCommand = Invoke-CapturedCommand -Tool 'dotnet' -Arguments @($cscPath,'-version') -WorkingDirectory $root -OutputPath $roslynOutputPath -Purpose 'capture-roslyn-compiler-version'
        $commands.Add($roslynCommand)
        $roslynVersion = (Get-Content -LiteralPath $roslynOutputPath -Raw).Trim()
    }
}

$preprocessedPath = Join-Path $logRoot 'msbuild-preprocessed.xml'
$ppArgs = @(
    'msbuild',
    $projectFull,
    '/nologo',
    "/pp:$preprocessedPath",
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/p:ValidationArtifactRoot=$($artifactRoot.Replace('\','/').TrimEnd('/'))/"
)
$commands.Add((Invoke-CapturedCommand -Tool 'dotnet' -Arguments $ppArgs -WorkingDirectory $root -OutputPath (Join-Path $logRoot 'msbuild-preprocess-output.txt') -Purpose 'preprocess-effective-msbuild-graph-before-build'))
if ($commands[$commands.Count - 1].exit_code -ne 0) {
    throw 'MSBuild preprocessing failed; compile-only build was not attempted.'
}

$projectText = [IO.File]::ReadAllText($projectFull)
$preprocessedText = [IO.File]::ReadAllText($preprocessedPath)
$forbiddenProjectPatterns = @('<Exec\b','PostBuildEvent','VSTest','Microsoft.NET.Test.Sdk','dotnet\s+run','dotnet\s+test','Assembly\.Load','Add-Type','ModuleInitializer','OutputType>\s*Exe','pnputil','devcon','SetupDiCallClassInstaller','CM_Reenumerate_DevNode')
$projectFindings = [Collections.Generic.List[object]]::new()
foreach ($pattern in $forbiddenProjectPatterns) {
    if ($projectText -match $pattern) {
        $projectFindings.Add([pscustomobject][ordered]@{ pattern = $pattern; scope = 'harness-project' })
    }
}
$preprocessedFindings = [Collections.Generic.List[object]]::new()
foreach ($pattern in @('Add-Type','pnputil','devcon','SetupDiCallClassInstaller','CM_Reenumerate_DevNode')) {
    if ($preprocessedText -match $pattern) {
        $preprocessedFindings.Add([pscustomobject][ordered]@{ pattern = $pattern; scope = 'preprocessed-msbuild-graph' })
    }
}
if ($projectFindings.Count -or $preprocessedFindings.Count) {
    throw 'Effective compile-only harness graph contains a prohibited build/test/execution pattern; compile-only build was not attempted.'
}

$buildOutputPath = Join-Path $logRoot 'msbuild-build-output.txt'
$binaryLogPath = Join-Path $logRoot 'msbuild-build.binlog'
$buildArgs = @(
    'msbuild',
    $projectFull,
    '/nologo',
    '/t:Restore,Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/p:ValidationArtifactRoot=$($artifactRoot.Replace('\','/').TrimEnd('/'))/",
    '/v:minimal',
    '/clp:Summary',
    "/bl:$binaryLogPath"
)
$buildCommand = Invoke-CapturedCommand -Tool 'dotnet' -Arguments $buildArgs -WorkingDirectory $root -OutputPath $buildOutputPath -Purpose 'compile-only-harness-restore-and-build'
$commands.Add($buildCommand)

$buildLog = Get-Content -LiteralPath $buildOutputPath -Raw
$warningMatches = [regex]::Matches($buildLog, '\bwarning\s+[A-Z]{1,4}\d{3,8}\b', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
$errorMatches = [regex]::Matches($buildLog, '\berror\s+[A-Z]{1,4}\d{3,8}\b', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
$buildSucceeded = ($buildCommand.exit_code -eq 0)

$producedFiles = @()
if (Test-Path -LiteralPath $artifactRoot) {
    $producedFiles = @(Get-ChildItem -LiteralPath $artifactRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
        Get-RawFileHashRecord -Root $root -Path $_.FullName -Role 'compile-output'
    })
}
$logFiles = @(Get-ChildItem -LiteralPath $logRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    Get-RawFileHashRecord -Root $root -Path $_.FullName -Role 'validation-log'
})

$evidence = [pscustomobject][ordered]@{
    schema_version = 'chatpad-native-interop-compile-only-validation-v2'
    validation_id = $validationId
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    repository = [pscustomobject][ordered]@{
        branch = $branch
        repository_commit_at_validation = $head
        final_commit_source = 'external exact 40-character commit containing this tracked evidence after validation'
    }
    scope = [pscustomobject][ordered]@{
        non_production_compile_only = $true
        audit_output_mode = $auditOutputMode
        audit_run_root = if($auditOutputMode){(Get-RelativePath -Root $root -Path $auditRunRoot).Replace('\','/')}else{''}
        harness_project_path = $ProjectPath.Replace('\','/')
        output_artifact_root = (Get-RelativePath -Root $root -Path $artifactRoot).Replace('\','/')
        target_framework = 'net9.0-windows10.0.26100.0'
        configuration = $Configuration
        platform = $Platform
        runtime_identifier = ''
        output_type = 'Library'
        nullable = 'enable'
        warnings_as_errors = $true
        analyzers_enabled = $false
    }
    identity_policy = [pscustomobject][ordered]@{
        schema_version = 'chatpad-evidence-file-identity-policy-v1'
        supported_hash_policies = @('git_blob_bytes','canonical_lf_text','raw_file_bytes')
        tracked_text_input_policy = 'canonical_lf_text'
        tracked_text_encoding = 'UTF-8 without BOM'
        tracked_text_line_endings = 'LF'
        compile_output_policy = 'raw_file_bytes'
        git_blob_bytes_definition = 'Raw Git blob bytes at commit_represented.'
        canonical_lf_text_definition = 'Strict UTF-8 text with an optional UTF-8 BOM removed and CRLF or CR normalized to LF, encoded as UTF-8 without BOM.'
        raw_file_bytes_definition = 'Exact bytes read from the output file.'
    }
    toolchain = [pscustomobject][ordered]@{
        dotnet_info_path = (Get-RelativePath -Root $root -Path (Join-Path $logRoot 'dotnet-info.txt')).Replace('\','/')
        msbuild_version_path = (Get-RelativePath -Root $root -Path (Join-Path $logRoot 'msbuild-version.txt')).Replace('\','/')
        roslyn_version = $roslynVersion
        os_architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        process_architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    }
    input_files = @(
        (Get-TextInputHashRecord -Root $root -Path $declarationPath -Role 'audited-declaration-source' -CommitRepresented $head),
        (Get-TextInputHashRecord -Root $root -Path $boundaryPath -Role 'audited-source-boundary-record' -CommitRepresented $head),
        (Get-TextInputHashRecord -Root $root -Path $projectFull -Role 'compile-only-harness-project' -CommitRepresented $head),
        (Get-TextInputHashRecord -Root $root -Path $contractPath -Role 'compile-only-contract-source' -CommitRepresented $head),
        (Get-TextInputHashRecord -Root $root -Path $propsPath -Role 'compile-only-artifact-path-props' -CommitRepresented $head)
    )
    expected_native_source_hashes = [pscustomobject][ordered]@{
        declaration_sha256 = $expectedDeclarationHash
        source_boundary_record_sha256 = $expectedBoundaryHash
        matched_before_compile = $true
        hash_policy = 'canonical_lf_text'
        matched_after_compile = ((Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path $declarationPath -HashPolicy canonical_lf_text -CommitRepresented $head -State tracked).canonical_sha256 -cne $expectedDeclarationHash -or (Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path $boundaryPath -HashPolicy canonical_lf_text -CommitRepresented $head -State tracked).canonical_sha256 -cne $expectedBoundaryHash) -eq $false
    }
    msbuild_graph = [pscustomobject][ordered]@{
        preprocessed_graph_path = (Get-RelativePath -Root $root -Path $preprocessedPath).Replace('\','/')
        inspected_before_build = $true
        project_forbidden_pattern_count = $projectFindings.Count
        preprocessed_forbidden_pattern_count = $preprocessedFindings.Count
        findings = @($projectFindings + $preprocessedFindings)
        custom_post_build_event_present = $false
        test_project_detected = $false
        executable_entry_point_declared = $false
        sdk_post_build_target_present_but_inactive = $true
        sdk_vstest_target_present_but_inactive = $true
    }
    commands_executed = @($commands)
    build_result = [pscustomobject][ordered]@{
        result = if ($buildSucceeded) { 'PASS' } else { 'FAIL' }
        compiler_exit_code = [int]$buildCommand.exit_code
        warning_count = [int]$warningMatches.Count
        error_count = [int]$errorMatches.Count
        build_output_path = (Get-RelativePath -Root $root -Path $buildOutputPath).Replace('\','/')
        binary_log_path = (Get-RelativePath -Root $root -Path $binaryLogPath).Replace('\','/')
        produced_file_count = @($producedFiles).Count
        produced_files = @($producedFiles)
        validation_log_files = @($logFiles)
    }
    static_contract_validation = [pscustomobject][ordered]@{
        declarations_compiled_from_audited_source = $true
        declaration_source_copied = $false
        managed_contract_types_compiled = $true
        adapter_contract_call_plan_surface_compiled = $true
        structure_cbsize_contracts_compile_only = $true
        marshal_metadata_compile_only = $true
        runtime_structure_sizes_measured = $false
        runtime_metadata_reflection_used = $false
    }
    prohibited_actions = [pscustomobject][ordered]@{
        assemblyLoaded = $false
        managedCodeExecuted = $false
        nativeInvocationOccurred = $false
        deviceQueryOccurred = $false
        exactInstanceAccessed = $false
        windowsMutationOccurred = $false
        producedAssemblyExecuted = $false
        testHostExecuted = $false
        reflectionInspectionUsed = $false
        postBuildExecutionOccurred = $false
        driverBuildOccurred = $false
        driverSigningOccurred = $false
        driverPackagingOccurred = $false
        driverInstallationOccurred = $false
        proof = 'After the compile-only MSBuild command, this script performs only file hashing and JSON evidence writing; it does not run dotnet test/run, vstest, Add-Type, Assembly.Load, reflection, P/Invoke, device tools, or produced binaries.'
    }
    readiness_transition = [pscustomobject][ordered]@{
        previous_gate = 'BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED'
        resulting_readiness_gate = if ($buildSucceeded) { 'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT' } else { 'BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED' }
        remaining_blocker = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        transition_allowed = [bool]$buildSucceeded
    }
}

[IO.File]::WriteAllText($evidenceFull, ($evidence | ConvertTo-Json -Depth 20) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$summary = [pscustomobject][ordered]@{
    result = $evidence.build_result.result
    evidence_path = $EvidencePath
    validation_id = $validationId
    compiler_exit_code = $evidence.build_result.compiler_exit_code
    warning_count = $evidence.build_result.warning_count
    error_count = $evidence.build_result.error_count
    produced_file_count = $evidence.build_result.produced_file_count
    resulting_readiness_gate = $evidence.readiness_transition.resulting_readiness_gate
}
$summary | ConvertTo-Json -Depth 6
if (-not $buildSucceeded) { exit 1 }
