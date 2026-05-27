function Connect-TeamsVoiceServices {
    [CmdletBinding()]
    param()
    try {
        Write-Host "    Connecting to Microsoft Teams..." -ForegroundColor DarkGray
        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
        $script:TenantContext.ConnectedTeams = $true
        $teamsSession = Get-CsTenant -ErrorAction SilentlyContinue
        if ($teamsSession) {
            $script:TenantContext.TenantId = $teamsSession.TenantId
            $script:TenantContext.TenantName = $teamsSession.DisplayName
            $script:TenantContext.CoexistenceMode = $teamsSession.TeamsUpgradeEffectiveMode
        }
        Write-Host "    Microsoft Teams connected." -ForegroundColor Green
    } catch { Write-Error "Failed to connect to Microsoft Teams: $_"; return $false }
    try {
        Write-Host "    Connecting to Microsoft Graph..." -ForegroundColor DarkGray
        $graphScopes = @('User.ReadWrite.All','Organization.Read.All','Domain.ReadWrite.All','Directory.Read.All')
        Connect-MgGraph -Scopes $graphScopes -NoWelcome -ErrorAction Stop
        $graphContext = Get-MgContext
        $script:TenantContext.AdminUpn = $graphContext.Account
        if (-not $script:TenantContext.TenantId) { $script:TenantContext.TenantId = $graphContext.TenantId }
        if (-not $script:TenantContext.TenantName) {
            $org = Get-MgOrganization -ErrorAction SilentlyContinue
            if ($org) { $script:TenantContext.TenantName = $org.DisplayName }
        }
        $script:TenantContext.ConnectedGraph = $true
        Write-Host "    Microsoft Graph connected." -ForegroundColor Green
    } catch { Write-Error "Failed to connect to Microsoft Graph: $_"; return $false }
    Write-AuditEntry -Action 'Connect' -Target $script:TenantContext.TenantName -Result 'Success' -Detail "Connected as $($script:TenantContext.AdminUpn)"
    return $true
}
