function Invoke-PortalBulkNumberAssignment {
    [CmdletBinding()]
    param([hashtable]$Body)
    $assignments = $Body.assignments
    if (-not $assignments -or $assignments.Count -eq 0) { return @{success=$false;error='No assignments provided'} }
    $results = @{ total=$assignments.Count; succeeded=0; failed=0; skipped=0; details=@() }
    foreach ($a in $assignments) {
        $upn = $a.UserPrincipalName
        $phone = Format-PhoneNumber -Number $a.PhoneNumber
        try {
            Set-CsPhoneNumberAssignment -Identity $upn -PhoneNumber $phone -PhoneNumberType DirectRouting -EA Stop
            $poolEntry = $script:NumberPool | Where-Object { $_.phoneNumber -eq $phone }
            if ($poolEntry) { $poolEntry.status = 'Assigned'; $poolEntry.assignedTo = $upn; $poolEntry.assignedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
            $results.succeeded++
            $results.details += @{upn=$upn;phone=$phone;status='Success'}
            Write-AuditEntry -Action 'BulkAssign' -Target $upn -Result 'Success' -Detail $phone
        } catch {
            $results.failed++
            $results.details += @{upn=$upn;phone=$phone;status='Error';error=$_.Exception.Message}
            Write-AuditEntry -Action 'BulkAssign' -Target $upn -Result 'Error' -Detail $_.Exception.Message
        }
    }
    $results.success = ($results.failed -eq 0)
    return $results
}
