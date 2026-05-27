function Get-PortalNormalizationRules {
    [CmdletBinding()]
    param()
    try {
        $dp = Get-CsTenantDialPlan -Identity Global -EA SilentlyContinue
        if ($dp -and $dp.NormalizationRules) {
            $rules = @($dp.NormalizationRules | ForEach-Object { @{name=$_.Name;pattern=$_.Pattern;translation=$_.Translation} })
            return @{ rules=$rules; source='tenant' }
        }
        return @{ rules=$script:VodacomDefaults.normalizationRules; source='defaults' }
    } catch {
        return @{ rules=$script:VodacomDefaults.normalizationRules; source='defaults'; warning=$_.Exception.Message }
    }
}
