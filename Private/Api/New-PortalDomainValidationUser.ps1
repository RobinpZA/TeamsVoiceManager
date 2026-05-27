function New-PortalDomainValidationUser {
    [CmdletBinding()]
    param([hashtable]$Body)
    $domainName = $Body.domainName
    $mailNickname = "tvm_validation_" + ($domainName -replace '\.','_')
    $upn = "$mailNickname@$domainName"
    $displayName = "TeamsVoice Validation ($domainName)"
    try {
        $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-AuditEntry -Action 'CreateValidationUser' -Target $upn -Result 'Skipped' -Detail 'Already exists'
            return @{ success = $true; upn = $upn; userId = $existing.Id; message = 'User already exists' }
        }
        $pass = -join ((65..90)+(97..122)+(48..57)+(33,35,36,37) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
        $userParams = @{
            AccountEnabled = $true; DisplayName = $displayName; MailNickname = $mailNickname
            UserPrincipalName = $upn; UsageLocation = 'ZA'
            PasswordProfile = @{ ForceChangePasswordNextSignIn = $false; Password = $pass }
        }
        $newUser = New-MgUser -BodyParameter $userParams -ErrorAction Stop
        if ($Body.assignLicense -eq $true) {
            $skus = Get-MgSubscribedSku -ErrorAction SilentlyContinue
            $teamsSku = $skus | Where-Object {
                $_.SkuPartNumber -in @('SPE_E5','SPE_E3','ENTERPRISEPREMIUM','ENTERPRISEPACK','O365_BUSINESS_PREMIUM')
            } | Where-Object { ($_.PrepaidUnits.Enabled - $_.ConsumedUnits) -gt 0 } | Select-Object -First 1
            if ($teamsSku) {
                Set-MgUserLicense -UserId $newUser.Id -AddLicenses @(@{SkuId=$teamsSku.SkuId}) -RemoveLicenses @() -ErrorAction Stop
                Write-AuditEntry -Action 'LicenseValidationUser' -Target $upn -Result 'Success' -Detail "Assigned $($teamsSku.SkuPartNumber)"
            } else {
                Write-AuditEntry -Action 'LicenseValidationUser' -Target $upn -Result 'Warning' -Detail 'No available Teams license'
            }
        }
        Write-AuditEntry -Action 'CreateValidationUser' -Target $upn -Result 'Success' -Detail 'Created'
        return @{ success = $true; upn = $upn; userId = $newUser.Id }
    } catch {
        Write-AuditEntry -Action 'CreateValidationUser' -Target $upn -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
