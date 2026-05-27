#Requires -Version 7.2

$script:ModuleRoot    = $PSScriptRoot
$script:TenantContext = @{
    TenantId       = $null
    TenantName     = $null
    AdminUpn       = $null
    CoexistenceMode = $null
    ConnectedTeams  = $false
    ConnectedGraph  = $false
}
$script:AuditLog   = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:NumberPool = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:HttpListener = $null
$script:PortalPort   = 8080

# Dot-source all Private functions
$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Recurse -Filter '*.ps1' -File |
        ForEach-Object {
            try   { . $_.FullName }
            catch { Write-Warning "Failed to import: $($_.Name) - $_" }
        }
}

# Dot-source all Public functions
$publicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Recurse -Filter '*.ps1' -File |
        ForEach-Object {
            try   { . $_.FullName }
            catch { Write-Warning "Failed to import: $($_.Name) - $_" }
        }
}

# Load Vodacom defaults
$defaultsPath = Join-Path $PSScriptRoot 'Config' 'VodacomDefaults.json'
if (Test-Path $defaultsPath) {
    $script:VodacomDefaults = Get-Content -Path $defaultsPath -Raw | ConvertFrom-Json -AsHashtable
} else {
    $script:VodacomDefaults = @{}
}

Export-ModuleMember -Function 'Start-TeamsVoiceManager'
