function Set-PortalAAResourceAssociation {
    [CmdletBinding()]
    param([hashtable]$Body)
    $raId = $Body.resourceAccountId
    $configId = $Body.configurationId
    $configType = $Body.configurationType  # 'AutoAttendant' or 'CallQueue'
    try {
        New-CsOnlineApplicationInstanceAssociation -Identities @($raId) -ConfigurationId $configId -ConfigurationType $configType -EA Stop
        Write-AuditEntry -Action 'AssociateRA' -Target $raId -Result 'Success' -Detail "$configType : $configId"
        return @{success=$true}
    } catch {
        Write-AuditEntry -Action 'AssociateRA' -Target $raId -Result 'Error' -Detail $_.Exception.Message
        return @{success=$false;error=$_.Exception.Message}
    }
}
