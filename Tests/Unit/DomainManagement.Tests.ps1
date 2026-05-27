Describe 'Domain Management Functions' {
    It 'Should have Add-PortalDomain function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Add-PortalDomain.ps1') |
            Should -Be $true
    }
    It 'Should have Get-PortalDomains function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Get-PortalDomains.ps1') |
            Should -Be $true
    }
    It 'Should have Get-PortalDomainTxtRecords function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Get-PortalDomainTxtRecords.ps1') |
            Should -Be $true
    }
    It 'Should have Invoke-PortalDomainVerification function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Invoke-PortalDomainVerification.ps1') |
            Should -Be $true
    }
    It 'Should have New-PortalDomainValidationUser function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'New-PortalDomainValidationUser.ps1') |
            Should -Be $true
    }
    It 'Should have Remove-PortalDomainValidationUserLicense function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Remove-PortalDomainValidationUserLicense.ps1') |
            Should -Be $true
    }

    Describe 'Add-PortalDomain input validation' {
        BeforeAll {
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Add-PortalDomain.ps1')

            # Stub Write-AuditEntry so it doesn't fail when called without module state
            function Write-AuditEntry {}
            # Stub Get-MgDomain / New-MgDomain to avoid real Graph calls
            function Get-MgDomain  { return $null }
            function New-MgDomain  { param($BodyParameter) return $BodyParameter }
        }
        It 'Should return success=false when domainName is empty' {
            $result = Add-PortalDomain -Body @{ domainName = '' }
            $result.success | Should -Be $false
            $result.error   | Should -Not -BeNullOrEmpty
        }
        It 'Should return success=false when domainName is whitespace' {
            $result = Add-PortalDomain -Body @{ domainName = '   ' }
            $result.success | Should -Be $false
        }
    }
}
