Describe 'Resource Account Functions' {
    It 'Should have Get-PortalResourceAccounts function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Get-PortalResourceAccounts.ps1') |
            Should -Be $true
    }
    It 'Should have New-PortalResourceAccount function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'New-PortalResourceAccount.ps1') |
            Should -Be $true
    }
    It 'Should have Set-PortalResourceAccountLicense function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Set-PortalResourceAccountLicense.ps1') |
            Should -Be $true
    }
    It 'Should have Set-PortalResourceAccountNumber function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Set-PortalResourceAccountNumber.ps1') |
            Should -Be $true
    }
    It 'Should have Set-PortalAAResourceAssociation function file' {
        Test-Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'Set-PortalAAResourceAssociation.ps1') |
            Should -Be $true
    }

    Describe 'New-PortalResourceAccount application IDs' {
        BeforeAll {
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Helpers' 'Format-PhoneNumber.ps1')
            . (Join-Path $PSScriptRoot '..' '..' 'Private' 'Api' 'New-PortalResourceAccount.ps1')

            $capturedAppId = $null
            function Write-AuditEntry {}
            function New-CsOnlineApplicationInstance {
                param([string]$UserPrincipalName, [string]$ApplicationId, [string]$DisplayName)
                $null = $UserPrincipalName, $DisplayName   # accepted by named parameters; not used by stub
                $script:capturedAppId = $ApplicationId
                return [PSCustomObject]@{ ObjectId = 'fake-id' }
            }
            function Get-MgSubscribedSku { return @() }
            # Return a valid object immediately so the poll loops exit on the first check without sleeping
            function Get-MgUser      { return [PSCustomObject]@{ Id = 'fake-id' } }
            function Get-CsOnlineUser { return [PSCustomObject]@{ Identity = 'fake-id' } }
            $script:NumberPool = [System.Collections.Generic.List[PSCustomObject]]::new()
        }
        It 'Should use AA application ID for AutoAttendant type' {
            New-PortalResourceAccount -Body @{
                displayName    = 'RA_AA_Test'
                upn            = 'ra_aa@contoso.com'
                type           = 'AutoAttendant'
                assignLicense  = $false
            }
            $script:capturedAppId | Should -Be 'ce933385-9390-45d1-9512-c8d228086b72'
        }
        It 'Should use CQ application ID for CallQueue type' {
            New-PortalResourceAccount -Body @{
                displayName    = 'RA_CQ_Test'
                upn            = 'ra_cq@contoso.com'
                type           = 'CallQueue'
                assignLicense  = $false
            }
            $script:capturedAppId | Should -Be '11cd3e2e-fccb-42ad-ad00-878b93575e07'
        }
    }
}
