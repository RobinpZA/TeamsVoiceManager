function Get-PortalAvailableNumbers {
    [CmdletBinding()]
    param()
    $available = @($script:NumberPool | Where-Object { $_.status -eq 'Available' })
    return @{ numbers = $available; count = $available.Count }
}
