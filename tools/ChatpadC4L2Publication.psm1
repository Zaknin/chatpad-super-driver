function Test-ChatpadC4L2PublicationReceipts {
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Receipts)
    if(-not $Receipts -or $Receipts.Count -eq 0){return $false}
    foreach($receipt in $Receipts){
        if($null -eq $receipt -or
           -not $receipt.PSObject.Properties['Verified'] -or
           -not $receipt.PSObject.Properties['SidecarCommittedLast'] -or
           $receipt.Verified -ne $true -or
           $receipt.SidecarCommittedLast -ne $true){return $false}
    }
    return $true
}
Export-ModuleMember -Function Test-ChatpadC4L2PublicationReceipts
