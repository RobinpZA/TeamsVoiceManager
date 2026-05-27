function Set-PortalUserLicense {
    [CmdletBinding()]
    param([string]$UserId, [hashtable]$Body)
    $action = $Body.action  # 'assign' or 'remove'
    $skuPartNumber = $Body.skuPartNumber
    if (-not $skuPartNumber) { $skuPartNumber = 'MCOEV' }
    try {
        $sku = Get-MgSubscribedSku -EA Stop | Where-Object { $_.SkuPartNumber -eq $skuPartNumber }
        if (-not $sku) { return @{success=$false;error="SKU $skuPartNumber not found in tenant"} }
        # Check usage location
        $user = Get-MgUser -UserId $UserId -Property 'UsageLocation' -EA SilentlyContinue
        if (-not $user.UsageLocation) {
            Update-MgUser -UserId $UserId -UsageLocation 'ZA' -EA Stop
            Write-AuditEntry -Action 'SetUsageLocation' -Target $UserId -Result 'Success' -Detail 'Set to ZA'
        }
        if ($action -eq 'remove') {
            Set-MgUserLicense -UserId $UserId -AddLicenses @() -RemoveLicenses @($sku.SkuId) -EA Stop
            Write-AuditEntry -Action 'RemoveLicense' -Target $UserId -Result 'Success' -Detail "Removed $skuPartNumber"
        } else {
            if (($sku.PrepaidUnits.Enabled - $sku.ConsumedUnits) -le 0) {
                return @{success=$false;error="No available $skuPartNumber licenses (0 remaining)"}
            }
            Set-MgUserLicense -UserId $UserId -AddLicenses @(@{SkuId=$sku.SkuId}) -RemoveLicenses @() -EA Stop
            Write-AuditEntry -Action 'AssignLicense' -Target $UserId -Result 'Success' -Detail "Assigned $skuPartNumber"
        }
        return @{success=$true;userId=$UserId;action=$action;sku=$skuPartNumber}
    } catch {
        Write-AuditEntry -Action 'SetLicense' -Target $UserId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
