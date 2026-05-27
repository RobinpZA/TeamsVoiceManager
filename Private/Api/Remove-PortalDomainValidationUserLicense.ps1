function Remove-PortalDomainValidationUserLicense {
    [CmdletBinding()]
    param([hashtable]$Body)
    $upn = $Body.upn
    try {
        $licenses = Get-MgUserLicenseDetail -UserId $upn -ErrorAction Stop
        if ($licenses) {
            $skuIds = @($licenses | ForEach-Object { $_.SkuId })
            Set-MgUserLicense -UserId $upn -AddLicenses @() -RemoveLicenses $skuIds -ErrorAction Stop
            Write-AuditEntry -Action 'RemoveValidationLicense' -Target $upn -Result 'Success' -Detail "Removed $($skuIds.Count) license(s)"
        }
        return @{ success = $true; upn = $upn }
    } catch {
        Write-AuditEntry -Action 'RemoveValidationLicense' -Target $upn -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
