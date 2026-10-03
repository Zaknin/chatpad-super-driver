Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Get-ChatpadWinUsbTrustDecision {
 [CmdletBinding()]param([System.Collections.IDictionary]$Evidence)
 $requirements=[ordered]@{
  ExactReviewedInf='Candidate INF differs from exact reviewed source.'
  InBoxOnly='Package is not exclusively INF/CAT referencing inbox WinUSB.'
  SignatureIntact='Catalog signature is absent or cryptographically invalid.'
  ExactSigner='Catalog signer is not the explicitly authorized existing certificate.'
  CatalogAuthenticode='Catalog Authenticode trust verification failed.'
  InfMembership='Exact INF catalog membership verification failed.'
  LocalMachineRoot='Exact local certificate absent from LocalMachine Root.'
  LocalMachinePublisher='Exact local certificate absent from LocalMachine TrustedPublisher.'
  LocalMachineChain='Catalog signer does not build a valid local-machine trust chain.'
  InBoxKernelPolicy='Microsoft inbox winusb.sys kernel-policy verification failed.'
  NormalMode='Effective ordinary code-integrity mode was not verified.'
 }
 $blockers=@()
 foreach($key in $requirements.Keys){if(-not $Evidence.Contains($key)-or$Evidence[$key] -isnot [bool]-or-not $Evidence[$key]){$blockers+=$requirements[$key]}}
 $ready=$blockers.Count -eq 0
 [pscustomobject]@{Schema=1;NormalWindowsInstallExpected=$ready;Reason=$(if($ready){'Local PnP Authenticode trust satisfied for reviewed INF/CAT-only package; Microsoft inbox kernel binary independently satisfies kernel policy. Actual staging/binding is untested.'}else{'Normal-Windows package prerequisites failed: '+($blockers -join ' ')});Blockers=$blockers;PhysicalInstallVerified=$false;ProductionDistributionApproved=$false;LocalCatalogKernelPolicyRequired=$false}
}
function Test-ChatpadArtifactHash {
 [CmdletBinding()]param([string]$Path,[string]$SHA256)
 if($SHA256 -notmatch '^[0-9A-Fa-f]{64}$'-or-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
 return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ieq $SHA256
}
Export-ModuleMember -Function Get-ChatpadWinUsbTrustDecision,Test-ChatpadArtifactHash
