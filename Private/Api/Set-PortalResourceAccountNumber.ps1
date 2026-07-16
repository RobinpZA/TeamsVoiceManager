function Set-PortalResourceAccountNumber {
    [CmdletBinding()]
    param([string]$ResourceAccountId, [hashtable]$Body)
    $phone = Format-PhoneNumber -Number $Body.phoneNumber
    try {
        $numberType = Resolve-PortalPhoneNumberType -PhoneNumber $phone
        Set-CsPhoneNumberAssignment -Identity $ResourceAccountId -PhoneNumber $phone -PhoneNumberType $numberType -EA Stop | Out-Null
        $poolEntry = $script:NumberPool | Where-Object { $_.phoneNumber -eq $phone }
        if ($poolEntry) { $poolEntry.status = 'Assigned'; $poolEntry.assignedTo = $ResourceAccountId; $poolEntry.assignedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
        Write-AuditEntry -Action 'AssignPhoneRA' -Target $ResourceAccountId -Result 'Success' -Detail $phone
        return @{success=$true;phoneNumber=$phone}
    } catch {
        Write-AuditEntry -Action 'AssignPhoneRA' -Target $ResourceAccountId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
