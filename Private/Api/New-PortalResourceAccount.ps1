function New-PortalResourceAccount {
    [CmdletBinding()]
    param([hashtable]$Body)
    $displayName = $Body.displayName
    $upn = $Body.upn
    $type = $Body.type  # 'AutoAttendant' or 'CallQueue'
    $assignLicense = $Body.assignLicense
    $phoneNumber = $Body.phoneNumber

    $appId = if ($type -eq 'AutoAttendant') { 'ce933385-9390-45d1-9512-c8d228086b72' } else { '11cd3e2e-fccb-42ad-ad00-878b93575e07' }

    try {
        # Create resource account
        $ra = New-CsOnlineApplicationInstance -UserPrincipalName $upn -ApplicationId $appId -DisplayName $displayName -EA Stop
        Write-AuditEntry -Action 'CreateRA' -Target $upn -Result 'Success' -Detail "Type: $type"

        # Wait for Azure AD replication — poll instead of fixed sleep to minimise UI block time
        $elapsed = 0
        while ($elapsed -lt 30) {
            if (Get-MgUser -UserId $upn -Property 'Id' -ErrorAction SilentlyContinue) { break }
            Start-Sleep -Seconds 2
            $elapsed += 2
        }

        # Assign license if requested
        if ($assignLicense) {
            try {
                $sku = Get-MgSubscribedSku -EA Stop | Where-Object { $_.SkuPartNumber -eq 'PHONESYSTEM_VIRTUALUSER' }
                if ($sku -and ($sku.PrepaidUnits.Enabled - $sku.ConsumedUnits) -gt 0) {
                    # Ensure usage location
                    $mgUser = Get-MgUser -UserId $upn -Property 'UsageLocation' -EA SilentlyContinue
                    if (-not $mgUser.UsageLocation) {
                        Update-MgUser -UserId $upn -UsageLocation 'ZA' -EA Stop
                    }
                    Set-MgUserLicense -UserId $upn -AddLicenses @(@{SkuId=$sku.SkuId}) -RemoveLicenses @() -EA Stop
                    Write-AuditEntry -Action 'LicenseRA' -Target $upn -Result 'Success' -Detail 'PHONESYSTEM_VIRTUALUSER'
                } else {
                    Write-AuditEntry -Action 'LicenseRA' -Target $upn -Result 'Warning' -Detail 'No available RA licenses'
                }
            } catch {
                Write-AuditEntry -Action 'LicenseRA' -Target $upn -Result 'Error' -Detail $_.Exception.Message
            }
        }

        # Assign phone number if provided
        if ($phoneNumber) {
            try {
                # Short poll to ensure the RA is fully replicated before number assignment
                $elapsed = 0
                while ($elapsed -lt 15) {
                    if (Get-CsOnlineUser -Identity $upn -ErrorAction SilentlyContinue) { break }
                    Start-Sleep -Seconds 2
                    $elapsed += 2
                }
                $formattedPhone = Format-PhoneNumber -Number $phoneNumber
                Set-CsPhoneNumberAssignment -Identity $upn -PhoneNumber $formattedPhone -PhoneNumberType DirectRouting -EA Stop
                $poolEntry = $script:NumberPool | Where-Object { $_.phoneNumber -eq $formattedPhone }
                if ($poolEntry) { $poolEntry.status = 'Assigned'; $poolEntry.assignedTo = $upn; $poolEntry.assignedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
                Write-AuditEntry -Action 'AssignPhoneRA' -Target $upn -Result 'Success' -Detail $formattedPhone
            } catch {
                Write-AuditEntry -Action 'AssignPhoneRA' -Target $upn -Result 'Error' -Detail $_.Exception.Message
            }
        }

        return @{ success = $true; objectId = $ra.ObjectId; upn = $upn; type = $type }
    } catch {
        Write-AuditEntry -Action 'CreateRA' -Target $upn -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
