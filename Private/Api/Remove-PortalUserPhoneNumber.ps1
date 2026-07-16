function Remove-PortalUserPhoneNumber {
    [CmdletBinding()]
    param([string]$UserId, [hashtable]$Body)
    $phone = Format-PhoneNumber -Number $Body.phoneNumber
    try {
        $numberType = Resolve-PortalPhoneNumberType -PhoneNumber $phone
        Remove-CsPhoneNumberAssignment -Identity $UserId -PhoneNumber $phone -PhoneNumberType $numberType -EA Stop | Out-Null
        $poolEntry = $script:NumberPool | Where-Object { $_.phoneNumber -eq $phone }
        if ($poolEntry) { $poolEntry.status = 'Available'; $poolEntry.assignedTo = $null; $poolEntry.assignedDate = $null }
        Write-AuditEntry -Action 'RemovePhone' -Target $UserId -Result 'Success' -Detail $phone
        return @{success=$true;userId=$UserId;phoneNumber=$phone}
    } catch {
        Write-AuditEntry -Action 'RemovePhone' -Target $UserId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
