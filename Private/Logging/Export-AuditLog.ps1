function Export-AuditLog {
    [CmdletBinding()] param()
    $ts  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Join-Path ([System.Environment]::GetFolderPath('MyDocuments')) 'TeamsVoiceManager' 'AuditLogs'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $csvPath = Join-Path $dir "AuditLog_$ts.csv"
    $script:AuditLog | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-AuditEntry -Action 'ExportAuditLog' -Target $csvPath -Result 'Success' -Detail "Exported $($script:AuditLog.Count) entries"
    return $csvPath
}
