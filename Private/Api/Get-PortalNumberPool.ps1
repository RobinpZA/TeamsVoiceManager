function Get-PortalNumberPool {
    [CmdletBinding()]
    param()
    $numbers = $script:NumberPool.ToArray()
    $stats = @{
        total     = $numbers.Count
        available = @($numbers | Where-Object {$_.status -eq 'Available'}).Count
        assigned  = @($numbers | Where-Object {$_.status -eq 'Assigned'}).Count
        reserved  = @($numbers | Where-Object {$_.status -eq 'Reserved'}).Count
    }
    return @{ numbers = $numbers; stats = $stats }
}
