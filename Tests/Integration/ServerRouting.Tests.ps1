Describe 'Server Routing' {
    It 'Should have Invoke-RequestRouter function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Server' 'Invoke-RequestRouter.ps1') | Should -Be $true
    }
    It 'Should have all API handler files' {
        $apiPath = Join-Path $PSScriptRoot '..' '..' 'Private' 'Api'
        $files = Get-ChildItem -Path $apiPath -Filter '*.ps1' -File
        $files.Count | Should -BeGreaterThan 20
    }
}
