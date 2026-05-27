function Get-PortalDashboard {
    [CmdletBinding()]
    param()
    $dashboard = @{
        tenant = @{ tenantId=$script:TenantContext.TenantId; tenantName=$script:TenantContext.TenantName; adminUpn=$script:TenantContext.AdminUpn; coexistenceMode=$script:TenantContext.CoexistenceMode }
        counts = @{ sbcGateways=0; voiceRoutes=0; pstnUsages=0; usersWithNumbers=0; resourceAccounts=0; autoAttendants=0; callQueues=0 }
        sbcGateways = @()
        licensing = @{ teamsPhoneStandard=@{total=0;consumed=0;available=0}; teamsPhoneRA=@{total=0;consumed=0;available=0} }
    }
    try {
        $gw = Get-CsOnlinePSTNGateway -EA SilentlyContinue
        if ($gw) {
            $dashboard.counts.sbcGateways = @($gw).Count
            $dashboard.sbcGateways = @($gw | ForEach-Object { @{ fqdn=$_.Identity; sipPort=$_.SipSignalingPort; enabled=$_.Enabled; mediaBypass=$_.MediaBypass } })
        }
        # Fallback: extract enrolled FQDNs from voice routes when no gateway objects exist
        if (-not $dashboard.counts.sbcGateways) {
            $vrFallback = Get-CsOnlineVoiceRoute -EA SilentlyContinue
            if ($vrFallback) {
                $fqdns = @($vrFallback | ForEach-Object { $_.OnlinePstnGatewayList } | Where-Object { $_ } | Select-Object -Unique)
                $dashboard.counts.sbcGateways = $fqdns.Count
                $dashboard.sbcGateways = @($fqdns | ForEach-Object { @{ fqdn=$_; sipPort=5061; enabled=$true; mediaBypass=$false } })
            }
        }
    } catch { Write-Verbose "GetDashboard/SbcGateways: $_" }
    try { $vr = Get-CsOnlineVoiceRoute -EA SilentlyContinue; if($vr){$dashboard.counts.voiceRoutes=@($vr).Count} } catch { Write-Verbose "GetDashboard/VoiceRoutes: $_" }
    try { $pu = Get-CsOnlinePstnUsage -Identity Global -EA SilentlyContinue; if($pu -and $pu.Usage){$dashboard.counts.pstnUsages=@($pu.Usage).Count} } catch { Write-Verbose "GetDashboard/PstnUsages: $_" }
    try { $vu = Get-CsOnlineUser -Filter "LineUri -ne ''" -EA SilentlyContinue; if($vu){$dashboard.counts.usersWithNumbers=@($vu).Count} } catch { Write-Verbose "GetDashboard/UsersWithNumbers: $_" }
    try { $ra = Get-CsOnlineApplicationInstance -EA SilentlyContinue; if($ra){$dashboard.counts.resourceAccounts=@($ra).Count} } catch { Write-Verbose "GetDashboard/ResourceAccounts: $_" }
    try { $aa = Get-CsAutoAttendant -EA SilentlyContinue; if($aa){$dashboard.counts.autoAttendants=@($aa).Count} } catch { Write-Verbose "GetDashboard/AutoAttendants: $_" }
    try { $cq = Get-CsCallQueue -EA SilentlyContinue; if($cq){$dashboard.counts.callQueues=@($cq).Count} } catch { Write-Verbose "GetDashboard/CallQueues: $_" }
    try {
        $skus = Get-MgSubscribedSku -EA SilentlyContinue
        $ps = $skus | Where-Object {$_.SkuPartNumber -eq 'MCOEV'}
        $pr = $skus | Where-Object {$_.SkuPartNumber -eq 'PHONESYSTEM_VIRTUALUSER'}
        if($ps){$dashboard.licensing.teamsPhoneStandard=@{total=$ps.PrepaidUnits.Enabled;consumed=$ps.ConsumedUnits;available=$ps.PrepaidUnits.Enabled-$ps.ConsumedUnits}}
        if($pr){$dashboard.licensing.teamsPhoneRA=@{total=$pr.PrepaidUnits.Enabled;consumed=$pr.ConsumedUnits;available=$pr.PrepaidUnits.Enabled-$pr.ConsumedUnits}}
    } catch { Write-Verbose "GetDashboard/Licensing: $_" }
    Write-AuditEntry -Action 'GetDashboard' -Target 'Dashboard' -Result 'Success' -Detail 'Retrieved dashboard data'
    return $dashboard
}
