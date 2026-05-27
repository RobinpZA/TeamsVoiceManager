function Get-PortalAuthStatus {
    [CmdletBinding()]
    param()

    $connected = $false

    if ($script:TenantContext.ConnectedTeams -and $script:TenantContext.ConnectedGraph) {
        # Live-check: verify the Teams session is still valid
        try {
            $null = Get-CsTenant -ErrorAction Stop
            $connected = $true
        } catch {
            # Token expired or connection lost — reset flags
            $script:TenantContext.ConnectedTeams = $false
            $script:TenantContext.ConnectedGraph  = $false
        }
    }

    return @{
        connected  = $connected
        tenantId   = $script:TenantContext.TenantId
        tenantName = $script:TenantContext.TenantName
        adminUpn   = $script:TenantContext.AdminUpn
    }
}
