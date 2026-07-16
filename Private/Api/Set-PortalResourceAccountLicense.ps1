function Set-PortalResourceAccountLicense {
    [CmdletBinding()]
    param([string]$ResourceAccountId, [hashtable]$Body)
    try {
        $sku = Get-MgSubscribedSku -EA Stop | Where-Object { $_.SkuPartNumber -eq 'PHONESYSTEM_VIRTUALUSER' }
        if (-not $sku) { return @{success=$false;error='PHONESYSTEM_VIRTUALUSER SKU not found'} }
        $mgUser = Get-MgUser -UserId $ResourceAccountId -Property 'UsageLocation' -EA SilentlyContinue
        if (-not $mgUser.UsageLocation) { Update-MgUser -UserId $ResourceAccountId -UsageLocation 'ZA' -EA Stop }
        Set-MgUserLicense -UserId $ResourceAccountId -AddLicenses @(@{SkuId=$sku.SkuId}) -RemoveLicenses @() -EA Stop
        Write-AuditEntry -Action 'LicenseRA' -Target $ResourceAccountId -Result 'Success' -Detail 'PHONESYSTEM_VIRTUALUSER'
        return @{success=$true}
    } catch {
        Write-AuditEntry -Action 'LicenseRA' -Target $ResourceAccountId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
