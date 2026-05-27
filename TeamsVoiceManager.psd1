@{
    RootModule        = 'TeamsVoiceManager.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f1c8e2-7b4d-4e6a-9f12-3c8d5e7a1b0f'
    Author            = 'Robin Pieterse'
    CompanyName       = 'Turrito Networks'
    Copyright         = '(c) 2026 Robin Pieterse. All rights reserved.'
    Description       = 'PowerShell module with embedded web portal for end-to-end Microsoft Teams Voice (Direct Routing) provisioning.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @('Start-TeamsVoiceManager')
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    RequiredModules    = @(
        @{ ModuleName = 'MicrosoftTeams'; ModuleVersion = '6.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.0.0' }
    )
    PrivateData = @{
        PSData = @{
            Tags       = @('Teams','Voice','DirectRouting','SBC','Vodacom','M365')
            ProjectUri = 'https://github.com/RobinpZA/TeamsVoiceManager'
        }
    }
}
