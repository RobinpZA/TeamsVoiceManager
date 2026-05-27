function Add-PortalDomain {
    [CmdletBinding()]
    param([hashtable]$Body)
    $domainName = $Body.domainName
    if ([string]::IsNullOrWhiteSpace($domainName)) {
        return @{ success = $false; error = 'Domain name is required' }
    }
    try {
        $existing = Get-MgDomain -DomainId $domainName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-AuditEntry -Action 'AddDomain' -Target $domainName -Result 'Skipped' -Detail 'Already exists'
            return @{ success = $true; domain = $domainName; message = 'Domain already exists'; isVerified = $existing.IsVerified }
        }
        New-MgDomain -BodyParameter @{ Id = $domainName } -ErrorAction Stop
        Write-AuditEntry -Action 'AddDomain' -Target $domainName -Result 'Success' -Detail 'Domain added'
        return @{ success = $true; domain = $domainName; message = 'Domain added. Retrieve TXT records next.' }
    } catch {
        Write-AuditEntry -Action 'AddDomain' -Target $domainName -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
