function Sync-PortalNumberPool {
    [CmdletBinding()]
    param()
    try {
        # Get-CsPhoneNumberAssignment caps at 1000 per call — paginate until no more results
        $allNumbers = [System.Collections.Generic.List[object]]::new()
        $pageSize   = 1000
        $skip       = 0
        do {
            $page = Get-CsPhoneNumberAssignment -NumberType DirectRouting -Top $pageSize -Skip $skip -ErrorAction Stop
            if ($page -and $page.Count -gt 0) {
                $allNumbers.AddRange([object[]]$page)
                $skip += $page.Count
            }
        } while ($page -and $page.Count -eq $pageSize)
    } catch {
        Write-AuditEntry -Action 'SyncNumberPool' -Target 'NumberPool' -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }

    $added = 0; $updated = 0

    foreach ($n in $allNumbers) {
        $phone = Format-PhoneNumber -Number $n.TelephoneNumber
        $isAssigned = -not [string]::IsNullOrEmpty($n.AssignedPstnTargetId)
        $status     = if ($isAssigned) { 'Assigned' } else { 'Available' }
        $assignedTo = if ($isAssigned) { $n.AssignedPstnTargetId } else { $null }

        $existing = $script:NumberPool | Where-Object { $_.phoneNumber -eq $phone }
        if ($existing) {
            # Update assignment status to reflect current Teams state
            $existing.status     = $status
            $existing.assignedTo = $assignedTo
            if ($isAssigned -and -not $existing.assignedDate) {
                $existing.assignedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            } elseif (-not $isAssigned) {
                $existing.assignedDate = $null
            }
            $updated++
        } else {
            $script:NumberPool.Add([PSCustomObject]@{
                phoneNumber  = $phone
                description  = $null
                status       = $status
                assignedTo   = $assignedTo
                assignedDate = if ($isAssigned) { (Get-Date -Format 'yyyy-MM-dd HH:mm') } else { $null }
            })
            $added++
        }
    }

    $stats = @{
        total     = $script:NumberPool.Count
        available = @($script:NumberPool | Where-Object { $_.status -eq 'Available' }).Count
        assigned  = @($script:NumberPool | Where-Object { $_.status -eq 'Assigned' }).Count
        reserved  = @($script:NumberPool | Where-Object { $_.status -eq 'Reserved' }).Count
    }

    Write-AuditEntry -Action 'SyncNumberPool' -Target 'NumberPool' -Result 'Success' -Detail "Added $added new, updated $updated existing from Teams"
    return @{ success = $true; added = $added; updated = $updated; stats = $stats }
}
