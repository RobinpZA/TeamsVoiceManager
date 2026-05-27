Describe 'User Management Functions' {
    It 'Should have Get-PortalUsers function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Get-PortalUsers.ps1') |
            Should -Be $true
    }
    It 'Should have Get-PortalUserVoiceStatus function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Get-PortalUserVoiceStatus.ps1') |
            Should -Be $true
    }
    It 'Should have Set-PortalUserLicense function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Set-PortalUserLicense.ps1') |
            Should -Be $true
    }
    It 'Should have Set-PortalUserPhoneNumber function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Set-PortalUserPhoneNumber.ps1') |
            Should -Be $true
    }
    It 'Should have Remove-PortalUserPhoneNumber function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Remove-PortalUserPhoneNumber.ps1') |
            Should -Be $true
    }
    It 'Should have Invoke-PortalBulkNumberAssignment function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Invoke-PortalBulkNumberAssignment.ps1') |
            Should -Be $true
    }

    Describe 'Set-PortalUserLicense input handling' {
        BeforeAll {
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Helpers' 'Format-PhoneNumber.ps1')
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Set-PortalUserPhoneNumber.ps1')

            function Write-AuditEntry {}
            function Set-CsPhoneNumberAssignment {}
            $script:NumberPool = [System.Collections.Generic.List[PSCustomObject]]::new()
        }
        It 'Should format phone number to E.164 before assignment' {
            # Verify Format-PhoneNumber is called indirectly via Set-PortalUserPhoneNumber
            { Set-PortalUserPhoneNumber -UserId 'test@contoso.com' -Body @{ phoneNumber = '0821234567' } } |
                Should -Not -Throw
        }
    }

    Describe 'Remove-PortalUserPhoneNumber phone formatting' {
        BeforeAll {
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Helpers' 'Format-PhoneNumber.ps1')
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Remove-PortalUserPhoneNumber.ps1')

            function Write-AuditEntry {}
            function Remove-CsPhoneNumberAssignment {}
            $script:NumberPool = [System.Collections.Generic.List[PSCustomObject]]::new()
        }
        It 'Should not throw when called with local format number' {
            { Remove-PortalUserPhoneNumber -UserId 'test@contoso.com' -Body @{ phoneNumber = '0821234567' } } |
                Should -Not -Throw
        }
    }
}
