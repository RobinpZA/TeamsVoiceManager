function Write-AuditEntry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Action,[Parameter(Mandatory)][string]$Target,[ValidateSet('Success','Warning','Error','Skipped','Info')][string]$Result='Info',[string]$Detail='')
    $entry = [PSCustomObject]@{timestamp=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss');action=$Action;target=$Target;result=$Result;detail=$Detail;admin=$script:TenantContext.AdminUpn}
    $script:AuditLog.Add($entry)
    $color = switch($Result){'Success'{'Green'}'Warning'{'Yellow'}'Error'{'Red'}'Skipped'{'DarkGray'}default{'White'}}
    Write-Host "  [$Action] $Target - $Detail" -ForegroundColor $color
}
