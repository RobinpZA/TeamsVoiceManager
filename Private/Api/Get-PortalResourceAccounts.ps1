function Get-PortalResourceAccounts {
    [CmdletBinding()]
    param()
    try {
        $ras = Get-CsOnlineApplicationInstance -EA SilentlyContinue
        $accounts = @($ras | ForEach-Object {
            $licDetails = Get-MgUserLicenseDetail -UserId $_.ObjectId -ErrorAction SilentlyContinue
            $hasLicense = [bool]($licDetails | Where-Object {
                $_.SkuPartNumber -eq 'PHONESYSTEM_VIRTUALUSER' -or
                $_.SkuPartNumber -eq 'MCOEV' -or
                $_.SkuPartNumber -like '*PHONE*'
            })
            $type = if ($_.ApplicationId -eq 'ce933385-9390-45d1-9512-c8d228086b72') { 'AutoAttendant' } else { 'CallQueue' }
            @{
                objectId          = $_.ObjectId
                displayName       = $_.DisplayName
                userPrincipalName = $_.UserPrincipalName
                applicationId     = $_.ApplicationId
                phoneNumber       = $_.PhoneNumber
                type              = $type
                hasLicense        = $hasLicense
            }
        })
        Write-AuditEntry -Action 'GetResourceAccounts' -Target 'RA' -Result 'Success' -Detail "$($accounts.Count) accounts"
        return @{ accounts = $accounts }
    } catch {
        return @{ accounts = @(); error = $_.Exception.Message }
    }
}
