function Set-PortalVoiceConfig {
    [CmdletBinding()]
    param([hashtable]$Body)
    $results = @{ steps = @(); success = $true }

    # Step 0: SBC Gateways
    $gatewayList = @($Body.gatewayList)
    $sipPort     = if ($Body.sipPort) { [int]$Body.sipPort } else { 5061 }
    if ($gatewayList.Count -gt 0) {
        foreach ($fqdn in $gatewayList) {
            if ([string]::IsNullOrWhiteSpace($fqdn)) { continue }
            try {
                $exGw = Get-CsOnlinePSTNGateway -Identity $fqdn -ErrorAction SilentlyContinue
                if ($exGw) {
                    Set-CsOnlinePSTNGateway -Identity $fqdn -SipSignalingPort $sipPort -ErrorAction Stop
                    $results.steps += @{step='SBC Gateway';status='Success';detail="Updated: $fqdn"}
                } else {
                    New-CsOnlinePSTNGateway -Fqdn $fqdn -SipSignalingPort $sipPort -Enabled $true -ErrorAction Stop
                    $results.steps += @{step='SBC Gateway';status='Success';detail="Created: $fqdn"}
                }
                Write-AuditEntry -Action 'SetSbcGateway' -Target $fqdn -Result 'Success' -Detail "Port: $sipPort"
            } catch {
                $results.steps += @{step='SBC Gateway';status='Error';detail=$_.Exception.Message}
                $results.success = $false
                Write-AuditEntry -Action 'SetSbcGateway' -Target $fqdn -Result 'Error' -Detail $_.Exception.Message
            }
        }
    }

    # Step 1: PSTN Usage
    $pstnUsage = $Body.pstnUsage
    if ($pstnUsage) {
        try {
            $ex = Get-CsOnlinePstnUsage -Identity Global -EA SilentlyContinue
            if ($ex -and $ex.Usage -contains $pstnUsage) {
                $results.steps += @{step='PSTN Usage';status='Skipped';detail='Already exists'}
            } else {
                Set-CsOnlinePstnUsage -Identity Global -Usage @{Add=$pstnUsage} -EA Stop
                $results.steps += @{step='PSTN Usage';status='Success';detail="Added: $pstnUsage"}
            }
            Write-AuditEntry -Action 'SetPstnUsage' -Target $pstnUsage -Result 'Success'
        } catch {
            $results.steps += @{step='PSTN Usage';status='Error';detail=$_.Exception.Message}
            $results.success = $false
            Write-AuditEntry -Action 'SetPstnUsage' -Target $pstnUsage -Result 'Error' -Detail $_.Exception.Message
        }
    }

    # Step 2: Voice Route
    $routeId = $Body.routeIdentity
    if ($routeId) {
        try {
            $exRoute = Get-CsOnlineVoiceRoute -Identity $routeId -EA SilentlyContinue
            $rp = @{ NumberPattern=$Body.numberPattern; OnlinePstnGatewayList=@($Body.gatewayList); Priority=[int]($Body.priority); OnlinePstnUsages=@($pstnUsage) }
            if ($exRoute) {
                Set-CsOnlineVoiceRoute -Identity $routeId @rp -EA Stop
                $results.steps += @{step='Voice Route';status='Success';detail="Updated: $routeId"}
            } else {
                New-CsOnlineVoiceRoute -Identity $routeId @rp -EA Stop
                $results.steps += @{step='Voice Route';status='Success';detail="Created: $routeId"}
            }
            Write-AuditEntry -Action 'SetVoiceRoute' -Target $routeId -Result 'Success'
        } catch {
            $results.steps += @{step='Voice Route';status='Error';detail=$_.Exception.Message}
            $results.success = $false
            Write-AuditEntry -Action 'SetVoiceRoute' -Target $routeId -Result 'Error' -Detail $_.Exception.Message
        }
    }

    # Step 3: Voice Routing Policy
    $polId = $Body.policyIdentity
    if (-not $polId) { $polId = 'Global' }
    if ($pstnUsage) {
        try {
            Set-CsOnlineVoiceRoutingPolicy -Identity $polId -OnlinePstnUsages @($pstnUsage) -EA Stop
            $results.steps += @{step='Routing Policy';status='Success';detail="Updated: $polId"}
            Write-AuditEntry -Action 'SetRoutingPolicy' -Target $polId -Result 'Success'
        } catch {
            $results.steps += @{step='Routing Policy';status='Error';detail=$_.Exception.Message}
            $results.success = $false
        }
    }

    # Step 4: Normalization Rules
    $normRules = $Body.normalizationRules
    $dpId = $Body.dialPlanIdentity
    if (-not $dpId) { $dpId = 'Global' }
    if ($normRules -and $normRules.Count -gt 0) {
        try {
            $ruleObjs = @()
            foreach ($r in $normRules) {
                $ruleObjs += New-CsVoiceNormalizationRule -Name $r.name -Parent $dpId -Pattern $r.pattern -Translation $r.translation -InMemory -EA Stop
            }
            Set-CsTenantDialPlan -Identity $dpId -NormalizationRules $ruleObjs -ErrorAction Stop
            $results.steps += @{step='Normalization Rules';status='Success';detail="Added $($ruleObjs.Count) rules"}
            Write-AuditEntry -Action 'SetNormRules' -Target $dpId -Result 'Success' -Detail "$($ruleObjs.Count) rules"
        } catch {
            $results.steps += @{step='Normalization Rules';status='Error';detail=$_.Exception.Message}
            $results.success = $false
        }
    }

    return $results
}
