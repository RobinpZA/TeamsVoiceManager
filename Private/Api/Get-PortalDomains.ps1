function Get-PortalDomains {
    [CmdletBinding()]
    param()
    try {
        $domains = Get-MgDomain -ErrorAction Stop
        $result = @($domains | ForEach-Object {
            @{
                id                 = $_.Id
                isVerified         = $_.IsVerified
                isDefault          = $_.IsDefault
                authenticationType = $_.AuthenticationType
                supportedServices  = $_.SupportedServices
                isSbcDomain        = ($_.Id -like '*.msdr.teams.vodacom.co.za')
            }
        })
        Write-AuditEntry -Action 'GetDomains' -Target 'Domains' -Result 'Success' -Detail "Retrieved $($result.Count) domains"
        return @{ domains = $result }
    } catch {
        Write-AuditEntry -Action 'GetDomains' -Target 'Domains' -Result 'Error' -Detail $_.Exception.Message
        return @{ domains = @(); error = $_.Exception.Message }
    }
}
