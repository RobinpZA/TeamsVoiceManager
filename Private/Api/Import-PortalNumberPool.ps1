function Import-PortalNumberPool {
    [CmdletBinding()]
    param([hashtable]$Body)
    $nums = $Body.numbers
    if (-not $nums -or $nums.Count -eq 0) { return @{success=$false;error='No numbers provided'} }
    $added = 0; $skipped = 0
    foreach ($n in $nums) {
        $phone = Format-PhoneNumber -Number $n.PhoneNumber
        $existing = $script:NumberPool | Where-Object { $_.phoneNumber -eq $phone }
        if ($existing) { $skipped++; continue }
        $script:NumberPool.Add([PSCustomObject]@{
            phoneNumber  = $phone
            description  = $n.Description
            status       = if ($n.PreAssignedUser) { 'Reserved' } else { 'Available' }
            assignedTo   = $n.PreAssignedUser
            assignedDate = $null
        })
        $added++
    }
    Write-AuditEntry -Action 'ImportNumbers' -Target 'NumberPool' -Result 'Success' -Detail "Added $added, skipped $skipped duplicates"
    return @{success=$true;added=$added;skipped=$skipped;total=$script:NumberPool.Count}
}
