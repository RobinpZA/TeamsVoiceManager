Describe 'NumberPool Functions' {
    It 'Should have Import-PortalNumberPool function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Import-PortalNumberPool.ps1') | Should -Be $true
    }
    It 'Should have Get-PortalNumberPool function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Get-PortalNumberPool.ps1') | Should -Be $true
    }
}
