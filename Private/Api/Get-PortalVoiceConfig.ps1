function Get-PortalVoiceConfig {
    [CmdletBinding()]
    param()
    $config = @{ gateways=@(); routes=@(); usages=@(); routingPolicies=@(); dialPlan=$null; defaults=$script:VodacomDefaults }
    try {
        $gw = Get-CsOnlinePSTNGateway -EA SilentlyContinue
        if ($gw) {
            $config.gateways = @($gw | ForEach-Object {
                @{ fqdn=$_.Identity; sipPort=$_.SipSignalingPort; enabled=$_.Enabled; mediaBypass=$_.MediaBypass; maxConcurrentSessions=$_.MaxConcurrentSessions }
            })
        }
        # Fallback: if no gateway objects returned, extract enrolled FQDNs from voice routes
        if (-not $config.gateways.Count) {
            $vrFallback = Get-CsOnlineVoiceRoute -EA SilentlyContinue
            if ($vrFallback) {
                $fqdns = @($vrFallback | ForEach-Object { $_.OnlinePstnGatewayList } | Where-Object { $_ } | Select-Object -Unique)
                $config.gateways = @($fqdns | ForEach-Object {
                    @{ fqdn=$_; sipPort=5061; enabled=$true; mediaBypass=$false; maxConcurrentSessions=$null }
                })
            }
        }
    } catch { Write-Verbose "GetVoiceConfig/SbcGateways: $_" }
    try {
        $vr = Get-CsOnlineVoiceRoute -EA SilentlyContinue
        if ($vr) { $config.routes = @($vr | ForEach-Object {
            @{ identity=$_.Identity; numberPattern=$_.NumberPattern; priority=$_.Priority; gatewayList=$_.OnlinePstnGatewayList; pstnUsages=$_.OnlinePstnUsages }
        }) }
    } catch { Write-Verbose "GetVoiceConfig/VoiceRoutes: $_" }
    try {
        $pu = Get-CsOnlinePstnUsage -Identity Global -EA SilentlyContinue
        if ($pu -and $pu.Usage) { $config.usages = @($pu.Usage) }
    } catch { Write-Verbose "GetVoiceConfig/PstnUsages: $_" }
    try {
        $pol = Get-CsOnlineVoiceRoutingPolicy -EA SilentlyContinue
        if ($pol) { $config.routingPolicies = @($pol | ForEach-Object { @{ identity=$_.Identity; pstnUsages=$_.OnlinePstnUsages } }) }
    } catch { Write-Verbose "GetVoiceConfig/RoutingPolicies: $_" }
    try {
        $dp = Get-CsTenantDialPlan -Identity Global -EA SilentlyContinue
        if ($dp) { $config.dialPlan = @{ identity=$dp.Identity; normalizationRules=@($dp.NormalizationRules | ForEach-Object { @{name=$_.Name;pattern=$_.Pattern;translation=$_.Translation} }) } }
    } catch { Write-Verbose "GetVoiceConfig/DialPlan: $_" }
    Write-AuditEntry -Action 'GetVoiceConfig' -Target 'VoiceRouting' -Result 'Success' -Detail "GW:$($config.gateways.Count) Routes:$($config.routes.Count)"
    return $config
}
