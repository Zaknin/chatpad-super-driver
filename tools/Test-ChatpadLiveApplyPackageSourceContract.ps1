[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot=[System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot,'..'))
$modulePath=Join-Path $repoRoot 'tools\ExactInstance\ChatpadLiveApplyPackageSourceContract.psm1'
$planPath=Join-Path $repoRoot 'tools\ExactInstance\contracts\chatpad-live-apply-package-source-plan.json'
$infPath=Join-Path $repoRoot 'src\driver\ChatpadFilter\package\ChatpadFilterExtension.inf'
$prototypePath=Join-Path $repoRoot 'prototypes\inf\ChatpadFilterExtension\ChatpadFilterExtension.inf'
Import-Module $modulePath -Force

$script:tests=0
$script:assertions=0
$tempRoot=Join-Path ([System.IO.Path]::GetTempPath()) ('chatpad-package-source-contract-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempRoot)

function Assert-Test([bool]$Condition,[string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw $Message }
}

function Pass-Test([string]$Name,[scriptblock]$Body) {
    & $Body
    $script:tests++
    Write-Output "PASS: $Name"
}

function Clone-Plan {
    return (([System.IO.File]::ReadAllText($planPath) | ConvertFrom-Json) | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
}

function Invoke-RejectedFixture {
    param([string]$Name,[scriptblock]$PlanMutation,[scriptblock]$InfMutation)
    $plan=Clone-Plan
    $inf=[System.IO.File]::ReadAllText($infPath)
    if ($null -ne $PlanMutation) { & $PlanMutation $plan | Out-Null }
    if ($null -ne $InfMutation) { $inf=& $InfMutation $inf }
    $fixtureDir=Join-Path $tempRoot ([guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $fixtureDir)
    $fixturePlan=Join-Path $fixtureDir 'plan.json'
    $fixtureInf=Join-Path $fixtureDir 'package.inf'
    [System.IO.File]::WriteAllText($fixturePlan,($plan | ConvertTo-Json -Depth 20),[System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($fixtureInf,$inf,[System.Text.UTF8Encoding]::new($false))
    $fixtureObject=[System.IO.File]::ReadAllText($fixturePlan) | ConvertFrom-Json
    $fixtureText=[System.IO.File]::ReadAllText($fixtureInf)
    $result=Test-ChatpadLiveApplyPackageSourceContract -PlanObject $fixtureObject -InfText $fixtureText
    Pass-Test $Name { Assert-Test (-not $result.is_valid -and $result.defect_count -gt 0) "$Name was not rejected." }
}

try {
    $baseline=Test-ChatpadLiveApplyPackageSourceContract
    Pass-Test 'canonical contract validates' { Assert-Test ($baseline.is_valid -and $baseline.defect_count -eq 0) "Canonical contract failed: $($baseline.defects -join '; ')" }
    Pass-Test 'canonical INF is outside prototypes' { Assert-Test (-not $infPath.StartsWith((Split-Path $prototypePath -Parent),[System.StringComparison]::OrdinalIgnoreCase)) 'Canonical INF is inside prototypes.' }
    Pass-Test 'prototype identity is exact' { Assert-Test ((Get-Item $prototypePath).Length -eq 1701 -and (Get-FileHash -Algorithm SHA256 $prototypePath).Hash -eq '821368368000A706BD2EAC0CB659090915C34E363F59F3F19F23D6DE0C4A05F4') 'Prototype identity changed.' }
    Pass-Test 'current status remains non-installable' { $p=Clone-Plan; Assert-Test ($p.status -match 'NOT_BUILT_NOT_CATALOGED_NOT_SIGNED_NOT_STAGED_NOT_INSTALLABLE') 'Non-installable status missing.' }
    Pass-Test 'future output inventory is complete' { $p=Clone-Plan; Assert-Test (@($p.future_p1b2_fields).Count -eq 23) 'Future output inventory count changed.' }

    Invoke-RejectedFixture 'prototype path selected as production' { param($p) $p.canonical_inf.path='prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf' } $null
    Invoke-RejectedFixture 'wrong INF hash' { param($p) $p.canonical_inf.sha256=('0'*64) } $null
    Invoke-RejectedFixture 'wrong driver project' { param($p) $p.production_driver_project.path='src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj' } $null
    Invoke-RejectedFixture 'wrong binary filename' { param($p) $p.driver_binary_filename='Wrong.sys' } $null
    Invoke-RejectedFixture 'wrong class' { param($p) $p.device_setup_class.name='System' } $null
    Invoke-RejectedFixture 'wrong ClassGuid' { param($p) $p.device_setup_class.guid='{00000000-0000-0000-0000-000000000000}' } $null
    Invoke-RejectedFixture 'wrong provider' { param($p) $p.provider='*' } $null
    Invoke-RejectedFixture 'wrong hardware ID' { param($p) $p.stable_hardware_ids=@('USB\VID_045E&PID_FFFF') } $null
    Invoke-RejectedFixture 'added broad model' $null { param($s) $s -replace '(\[Models\.NTamd64\.10\.0\.\.\.22000\]\r?\n)',"`$1%Broad% = ChatpadFilter_Install, USB\Class_00`r`n" }
    Invoke-RejectedFixture 'missing architecture decoration' $null { param($s) $s.Replace('Models,NTamd64.10.0...22000','Models').Replace('[Models.NTamd64.10.0...22000]','[Models]') }
    Invoke-RejectedFixture 'changed filter order' $null { param($s) $s.Replace('FilterPosition = Lower','FilterPosition = Upper') }
    Invoke-RejectedFixture 'missing catalog filename' $null { param($s) $s -replace '(?m)^CatalogFile.*\r?\n','' }
    Invoke-RejectedFixture 'test signing classified as production' { param($p) $p.signing_policy.test_signing_permitted_for_live_attempt=$true } $null
    Invoke-RejectedFixture 'placeholder catalog hash' { param($p) $p | Add-Member -NotePropertyName catalog_sha256 -NotePropertyValue ('0'*64) } $null
    Invoke-RejectedFixture 'placeholder signer' { param($p) $p | Add-Member -NotePropertyName package_signer_subject -NotePropertyValue 'PLACEHOLDER' } $null
    Invoke-RejectedFixture 'first enumerated candidate' { param($p) $p.caller_controls.first_or_best_driver_fallback_permitted=$true } $null
    Invoke-RejectedFixture 'best-ranked-only candidate' { param($p) $p.candidate_rule.prohibited_strategies=@($p.candidate_rule.prohibited_strategies | Where-Object { $_ -ne 'highest-ranked candidate without identity matching' }) } $null
    Invoke-RejectedFixture 'zero-match acceptance' { param($p) $p.candidate_rule.zero_exact_matches='ELIGIBLE' } $null
    Invoke-RejectedFixture 'multiple-match acceptance' { param($p) $p.candidate_rule.multiple_exact_matches='ELIGIBLE' } $null
    Invoke-RejectedFixture 'missing future output field' { param($p) $p.future_p1b2_fields=@($p.future_p1b2_fields | Where-Object { $_ -ne 'reproducibility_result' }) } $null
    Invoke-RejectedFixture 'added source file' { param($p) $p.package_source_inventory += [pscustomobject]@{role='extra';path='README.md';sha256=(Get-FileHash -Algorithm SHA256 (Join-Path $repoRoot 'README.md')).Hash} } $null
    Invoke-RejectedFixture 'caller-selected package path' { param($p) $p.caller_controls.caller_selected_package_path_permitted=$true } $null
    Invoke-RejectedFixture 'wrong blocker' { param($p) $p.blocker='WRONG_BLOCKER' } $null
    Invoke-RejectedFixture 'wrong next task' { param($p) $p.next_task='TASK 8I-P1C' } $null

    Write-Output "TASK 8I-P1B-1-C1 package-source focused tests: $script:tests tests / $script:assertions assertions"
    Write-Output 'Build/package/catalog/signing/staging/native/device/authorization/binding/mutation counters: 0/0/0/0/0/0/0/0/0/0'
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
