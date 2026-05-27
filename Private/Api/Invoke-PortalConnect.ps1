function Invoke-PortalConnect {
    [CmdletBinding()]
    param()
    $result = Connect-TeamsVoiceServices
    if ($result) {
        return @{
            success    = $true
            tenantId   = $script:TenantContext.TenantId
            tenantName = $script:TenantContext.TenantName
            adminUpn   = $script:TenantContext.AdminUpn
        }
    }
    return @{ success = $false; error = 'Authentication failed. Check the PowerShell window for details.' }
}
