function Set-PortalNormalizationRules {
    [CmdletBinding()]
    param([hashtable]$Body)
    $rules = $Body.rules
    $dpId = $Body.dialPlanIdentity
    if (-not $dpId) { $dpId = 'Global' }
    $replaceAll = $Body.replaceAll
    if (-not $rules -or $rules.Count -eq 0) { return @{success=$false;error='No rules provided'} }
    try {
        $objs = @()
        foreach ($r in $rules) { $objs += New-CsVoiceNormalizationRule -Name $r.name -Parent $dpId -Pattern $r.pattern -Translation $r.translation -InMemory -EA Stop }
        if ($replaceAll) { Set-CsTenantDialPlan -Identity $dpId -NormalizationRules $objs -EA Stop }
        else { Set-CsTenantDialPlan -Identity $dpId -NormalizationRules @{Add=$objs} -EA Stop }
        Write-AuditEntry -Action 'SetNormRules' -Target $dpId -Result 'Success' -Detail "$($objs.Count) rules (replace=$replaceAll)"
        return @{success=$true;count=$objs.Count}
    } catch {
        Write-AuditEntry -Action 'SetNormRules' -Target $dpId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
