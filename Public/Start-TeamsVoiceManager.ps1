function Start-TeamsVoiceManager {
    <#
    .SYNOPSIS
        Launches the TeamsVoiceManager web portal.
    .PARAMETER Port
        TCP port for the local web server. Default: 8080.
    .PARAMETER NoBrowser
        If specified, the portal URL is printed but the browser is not opened automatically.
    .EXAMPLE
        Start-TeamsVoiceManager
    .EXAMPLE
        Start-TeamsVoiceManager -Port 9090 -NoBrowser
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 65535)]
        [int]$Port = 8080,
        [switch]$NoBrowser
    )

    $script:PortalPort = $Port
    $portalUrl = "http://127.0.0.1:$Port/"
    $moduleVersion = (Get-Module -Name 'TeamsVoiceManager' -ErrorAction SilentlyContinue)?.Version ?? '0.1.0'

    Write-Host ""
    Write-Host "  =========================================" -ForegroundColor Cyan
    Write-Host "    TeamsVoiceManager v$moduleVersion" -ForegroundColor Cyan
    Write-Host "    Teams Voice Direct Routing Provisioning" -ForegroundColor Cyan
    Write-Host "  =========================================" -ForegroundColor Cyan
    Write-Host ""

    # Required modules are declared in RequiredModules in the manifest — PowerShell enforces them at import time.
    Write-Host "  Required modules available." -ForegroundColor Green

    # Reset auth state — every portal start requires fresh browser sign-in
    $script:TenantContext.ConnectedTeams = $false
    $script:TenantContext.ConnectedGraph  = $false
    $script:TenantContext.TenantId        = $null
    $script:TenantContext.TenantName      = $null
    $script:TenantContext.AdminUpn        = $null
    $script:TenantContext.CoexistenceMode = $null

    Write-Host ""
    Write-Host "  Starting portal on $portalUrl" -ForegroundColor Cyan
    Write-Host "  Sign in via the browser when the portal opens." -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C or click Close Portal in the browser to stop." -ForegroundColor DarkGray
    Write-Host ""

    if (-not $NoBrowser) { Start-Process $portalUrl }
    else { Write-Host "  Portal URL: $portalUrl" -ForegroundColor Yellow }

    try {
        Start-HttpListener -Port $Port
    } catch {
        if ($_.Exception.Message -notlike '*listener was stopped*') { Write-Error "Portal error: $_" }
    } finally {
        if ($script:HttpListener) { $script:HttpListener.Stop(); $script:HttpListener.Close(); $script:HttpListener = $null }
        Write-Host ""
        Write-Host "  Portal stopped." -ForegroundColor Yellow
        if ($script:AuditLog.Count -gt 0) {
            Write-Host "  $($script:AuditLog.Count) actions recorded this session." -ForegroundColor Cyan
            $export = Read-Host "  Export audit log? (Y/n)"
            if ($export -ne 'n') {
                $exportPath = Export-AuditLog
                Write-Host "  Audit log exported to: $exportPath" -ForegroundColor Green
            }
        }
        Write-Host "  TeamsVoiceManager session ended." -ForegroundColor Cyan
        Write-Host ""
    }
}
