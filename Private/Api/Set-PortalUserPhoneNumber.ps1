function Set-PortalUserPhoneNumber {
    [CmdletBinding()]
    param([string]$UserId, [hashtable]$Body)
    $phone = Format-PhoneNumber -Number $Body.phoneNumber
    try {
        Set-CsPhoneNumberAssignment -Identity $UserId -PhoneNumber $phone -PhoneNumberType DirectRouting -EA Stop
        # Update number pool status
        $poolEntry = $script:NumberPool | Where-Object { $_.phoneNumber -eq $phone }
        if ($poolEntry) { $poolEntry.status = 'Assigned'; $poolEntry.assignedTo = $UserId; $poolEntry.assignedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
        Write-AuditEntry -Action 'AssignPhone' -Target $UserId -Result 'Success' -Detail $phone
        return @{success=$true;userId=$UserId;phoneNumber=$phone}
    } catch {
        Write-AuditEntry -Action 'AssignPhone' -Target $UserId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
