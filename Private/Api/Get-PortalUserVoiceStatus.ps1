function Get-PortalUserVoiceStatus {
    [CmdletBinding()]
    param([string]$UserId)
    try {
        $u = Get-CsOnlineUser -Identity $UserId -EA Stop
        $hasLicense = Test-TeamsPhoneLicense -UserId $UserId
        $licenses = @()
        try { $licenses = @(Get-MgUserLicenseDetail -UserId $UserId -EA Stop | ForEach-Object { $_.SkuPartNumber }) } catch { Write-Verbose "GetUserVoiceStatus/Licenses ($UserId): $_" }
        return @{
            displayName            = $u.DisplayName
            userPrincipalName      = $u.UserPrincipalName
            objectId               = $u.Identity
            phoneNumber            = $u.LineUri
            phoneNumberType        = $u.PhoneNumberType
            enterpriseVoiceEnabled = $u.EnterpriseVoiceEnabled
            voiceRoutingPolicy     = $u.OnlineVoiceRoutingPolicy
            dialPlan               = $u.TenantDialPlan
            hasPhoneLicense        = $hasLicense
            licenses               = $licenses
            usageLocation          = $u.UsageLocation
            teamsUpgradeMode       = $u.TeamsUpgradeEffectiveMode
        }
    } catch {
        return @{ error = $_.Exception.Message }
    }
}
