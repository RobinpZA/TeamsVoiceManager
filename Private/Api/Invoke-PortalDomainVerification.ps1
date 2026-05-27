function Invoke-PortalDomainVerification {
    [CmdletBinding()]
    param([string]$DomainName)
    try {
        Confirm-MgDomain -DomainId $DomainName -ErrorAction Stop
        Write-AuditEntry -Action 'VerifyDomain' -Target $DomainName -Result 'Success' -Detail 'Domain verified'
        return @{ verified = $true; domain = $DomainName }
    } catch {
        Write-AuditEntry -Action 'VerifyDomain' -Target $DomainName -Result 'Error' -Detail $_.Exception.Message
        return @{ verified = $false; domain = $DomainName; error = $_.Exception.Message }
    }
}
