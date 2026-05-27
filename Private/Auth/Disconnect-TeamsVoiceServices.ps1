function Disconnect-TeamsVoiceServices {
    [CmdletBinding()]
    param()
    try { Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue } catch { Write-Verbose "Disconnect-MicrosoftTeams: $_" }
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch { Write-Verbose "Disconnect-MgGraph: $_" }
    $script:TenantContext.TenantId        = $null
    $script:TenantContext.TenantName      = $null
    $script:TenantContext.AdminUpn        = $null
    $script:TenantContext.CoexistenceMode = $null
    $script:TenantContext.ConnectedTeams  = $false
    $script:TenantContext.ConnectedGraph  = $false
    Write-AuditEntry -Action 'Disconnect' -Target 'Session' -Result 'Info' -Detail 'Signed out of Microsoft services'
}
