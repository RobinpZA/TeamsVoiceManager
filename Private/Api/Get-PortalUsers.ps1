function Get-PortalUsers {
    [CmdletBinding()]
    param([string]$Search, [string]$Page, [string]$PageSize, [string]$WithPhoneNumbers, [string]$WithoutPhoneNumbers)
    if (-not $PageSize -or $PageSize -eq '0') { $PageSize = '50' }
    if (-not $Page -or $Page -eq '0') { $Page = '1' }
    $ps = [int]$PageSize; $pg = [int]$Page
    # Sanitize search input before use in OPATH filter — strip single quotes (OPATH delimiter) and control chars
    $safeSearch = ($Search -replace "['\x00-\x1F]", '').Trim()
    try {
        if ($WithoutPhoneNumbers -eq 'true') {
            # Return all users that do NOT have a phone number assigned
            $users = Get-CsOnlineUser -Filter "LineUri -eq ''" -ResultSize 1000 -EA Stop
        } elseif ($WithPhoneNumbers -eq 'true') {
            # Return all users that currently have a phone number assigned
            # Use -ne '' rather than -ne $null — OPATH does not accept PowerShell null literals
            $users = Get-CsOnlineUser -Filter "LineUri -ne ''" -ResultSize 1000 -EA Stop
        } elseif ($safeSearch) {
            # Search both DisplayName and UPN so that email-format queries resolve correctly
            try {
                $users = Get-CsOnlineUser -Filter "DisplayName -like '*$safeSearch*' -or UserPrincipalName -like '*$safeSearch*'" -ResultSize 200 -EA Stop
            } catch {
                # Fallback if the driver does not support -or: choose filter based on input shape
                if ($safeSearch -like '*@*') {
                    $users = Get-CsOnlineUser -Filter "UserPrincipalName -like '*$safeSearch*'" -ResultSize 200 -EA Stop
                } else {
                    $users = Get-CsOnlineUser -Filter "DisplayName -like '*$safeSearch*'" -ResultSize 200 -EA Stop
                }
            }
        } else {
            $users = Get-CsOnlineUser -ResultSize ($ps * $pg) -EA Stop
        }
        # Exclude guest users — their UPN contains the #EXT# marker used by Azure AD B2B
        $users = @($users | Where-Object { $_.UserPrincipalName -notlike '*#EXT#*' })
        $total = @($users).Count
        $paged = @($users) | Select-Object -Skip (($pg - 1) * $ps) -First $ps
        $result = @($paged | ForEach-Object {
            # Use FeatureTypes (already on the CsOnlineUser object) to avoid a Graph call per user.
            # Resource accounts use PhoneSystemVirtualUser; regular users use PhoneSystem.
            # Fall back to individual license check only when FeatureTypes is absent (older module versions).
            $hasLicense = if ($null -ne $_.FeatureTypes) {
                [bool]($_.FeatureTypes -contains 'PhoneSystem' -or $_.FeatureTypes -contains 'PhoneSystemVirtualUser')
            } else {
                Test-TeamsPhoneLicense -UserId $_.UserPrincipalName
            }
            # Strip the tel: URI scheme that Teams stores on LineUri
            $phoneNumber = if ($_.LineUri) { $_.LineUri -replace '^tel:', '' } else { $null }
            # OnlineVoiceRoutingPolicy may be a complex object in Teams module 6.x — coerce to string and strip Tag: prefix
            $policy = if ($_.OnlineVoiceRoutingPolicy) {
                ([string]$_.OnlineVoiceRoutingPolicy) -replace '^Tag:', ''
            } else { 'Global' }
            # TenantDialPlan may also be a complex object — same coercion
            $dialPlan = if ($_.TenantDialPlan) {
                ([string]$_.TenantDialPlan) -replace '^Tag:', ''
            } else { 'Global' }
            @{
                displayName            = $_.DisplayName
                userPrincipalName      = $_.UserPrincipalName
                objectId               = $_.Identity
                phoneNumber            = $phoneNumber
                enterpriseVoiceEnabled = $_.EnterpriseVoiceEnabled
                voiceRoutingPolicy     = $policy
                dialPlan               = $dialPlan
                hasPhoneLicense        = $hasLicense
                usageLocation          = $_.UsageLocation
            }
        })
        return @{ users = $result; total = $total; page = $pg; pageSize = $ps }
    } catch {
        Write-AuditEntry -Action 'GetUsers' -Target 'Users' -Result 'Error' -Detail $_.Exception.Message
        return @{ users = @(); total = 0; error = $_.Exception.Message }
    }
}
