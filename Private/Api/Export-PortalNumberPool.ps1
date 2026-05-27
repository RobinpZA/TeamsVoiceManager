function Export-PortalNumberPool {
    [CmdletBinding()]
    param()
    return @{ numbers = $script:NumberPool.ToArray() }
}
