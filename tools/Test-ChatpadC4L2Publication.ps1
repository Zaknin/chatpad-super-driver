[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4L2Publication.psm1') -Force

$good=@([pscustomobject]@{Verified=$true;SidecarCommittedLast=$true},[pscustomobject]@{Verified=$true;SidecarCommittedLast=$true})
if(-not (Test-ChatpadC4L2PublicationReceipts $good)){throw 'All verified payload receipts should pass.'}
if(Test-ChatpadC4L2PublicationReceipts @([pscustomobject]@{Verified=$false;SidecarCommittedLast=$true})){throw 'A receipt with failed payload readback must fail.'}
if(Test-ChatpadC4L2PublicationReceipts @([pscustomobject]@{Verified=$true;SidecarCommittedLast=$false})){throw 'A receipt without a final sidecar must fail.'}
if(Test-ChatpadC4L2PublicationReceipts @([pscustomobject]@{Verified=$true})){throw 'A receipt missing sidecar status must fail.'}
if(Test-ChatpadC4L2PublicationReceipts @()){throw 'An empty receipt set must fail.'}
Write-Output 'C4L2 atomic publication receipt regressions: 5/5 PASS'
