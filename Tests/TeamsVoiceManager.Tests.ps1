Describe 'TeamsVoiceManager Module' {
    BeforeAll {
        $script:modulePath = Join-Path $PSScriptRoot '..' 'TeamsVoiceManager.psd1'
    }
    It 'Should have a valid module manifest' {
        { Test-ModuleManifest -Path $script:modulePath -ErrorAction Stop } | Should -Not -Throw
    }
    It 'Should import without errors' {
        { Import-Module $script:modulePath -Force -ErrorAction Stop } | Should -Not -Throw
    }
    It 'Should export Start-TeamsVoiceManager' {
        Import-Module $script:modulePath -Force
        $cmds = Get-Command -Module TeamsVoiceManager
        $cmds.Name | Should -Contain 'Start-TeamsVoiceManager'
    }
    It 'Should only export one function' {
        Import-Module $script:modulePath -Force
        $cmds = Get-Command -Module TeamsVoiceManager
        @($cmds).Count | Should -Be 1
    }
}
