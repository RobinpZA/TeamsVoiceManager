function Get-PortalDomainTxtRecords {
    [CmdletBinding()]
    param([string]$DomainName)
    try {
        $records = Get-MgDomainVerificationDnsRecord -DomainId $DomainName -ErrorAction Stop
        $txtRecords = @($records | Where-Object { $_.RecordType -eq 'Txt' } | ForEach-Object {
            @{ recordType = $_.RecordType; label = $_.Label; text = $_.AdditionalProperties.text; ttl = $_.Ttl }
        })
        $allRecords = @($records | ForEach-Object {
            @{ recordType = $_.RecordType; label = $_.Label; text = $_.AdditionalProperties.text; ttl = $_.Ttl }
        })
        Write-AuditEntry -Action 'GetTxtRecords' -Target $DomainName -Result 'Success' -Detail "Found $($txtRecords.Count) TXT record(s)"
        return @{ records = $txtRecords; allRecords = $allRecords; domain = $DomainName }
    } catch {
        Write-AuditEntry -Action 'GetTxtRecords' -Target $DomainName -Result 'Error' -Detail $_.Exception.Message
        return @{ records = @(); error = $_.Exception.Message }
    }
}
